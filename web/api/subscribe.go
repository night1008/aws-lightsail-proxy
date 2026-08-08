package handler

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"

	"github.com/aliyun/aliyun-oss-go-sdk/oss"
)

const (
	outputObjectKeyPrefix = "outputs/combined-configs"
)

// InstanceOutput matches the JSON structure produced by Terraform
type InstanceOutput struct {
	InstanceName    string `json:"instance_name"`
	PublicIPAddress string `json:"public_ip_address"`
	StaticIP        string `json:"static_ip"`

	ShadowsocksConfig *ShadowsocksConfig `json:"shadowsocks_config"`
	ShadowsocksURL    *string            `json:"shadowsocks_url"`
	HysteriaConfig    *HysteriaConfig    `json:"hysteria_config"`
	HysteriaURL       *string            `json:"hysteria_url"`
	XrayConfig        *XrayConfig        `json:"xray_config"`
	XrayURL           *string            `json:"xray_url"`
}

type ShadowsocksConfig struct {
	LocalPort  int      `json:"local_port"`
	Method     string   `json:"method"`
	Mode       string   `json:"mode"`
	Password   string   `json:"password"`
	Server     []string `json:"server"`
	ServerPort int      `json:"server_port"`
	Timeout    int      `json:"timeout"`
}

type HysteriaConfig struct {
	Listen   int    `json:"listen"`
	Password string `json:"password"`
	SNI      string `json:"sni"`
	ProxyURL string `json:"proxy_url"`
}

type XrayConfig struct {
	Port      int    `json:"port"`
	UUID      string `json:"uuid"`
	PublicKey string `json:"public_key"`
	SNI       string `json:"sni"`
	ProxyURL  string `json:"proxy_url"`
}

func SubscribeHandler(w http.ResponseWriter, r *http.Request) {
	authToken := os.Getenv("AUTH_TOKEN")
	values := r.URL.Query()
	inputAuthToken := values.Get("auth_token")
	if inputAuthToken != authToken {
		response(w, http.StatusForbidden, H{"error": "invalid auth token"})
		return
	}

	region := os.Getenv("ALICLOUD_REGION")
	accessKey := os.Getenv("ALICLOUD_ACCESS_KEY")
	accessKeySecret := os.Getenv("ALICLOUD_SECRET_KEY")
	bucketName := os.Getenv("ALICLOUD_BUCKET")

	client, err := getOSSClient(region, accessKey, accessKeySecret)
	if err != nil {
		response(w, http.StatusInternalServerError, H{"error": err.Error()})
		return
	}

	bucket, err := client.Bucket(bucketName)
	if err != nil {
		response(w, http.StatusInternalServerError, H{"error": err.Error()})
		return
	}

	listObjects, err := bucket.ListObjects(oss.Prefix(outputObjectKeyPrefix))
	if err != nil {
		response(w, http.StatusInternalServerError, H{"error": err.Error()})
		return
	}

	var urls []string
	for _, o := range listObjects.Objects {
		object, err := bucket.GetObject(o.Key)
		if err != nil {
			response(w, http.StatusInternalServerError, H{"error": err.Error()})
			return
		}
		defer object.Close()
		body, err := io.ReadAll(object)
		if err != nil {
			response(w, http.StatusInternalServerError, H{"error": err.Error()})
			return
		}

		var instance InstanceOutput
		if err := json.Unmarshal(body, &instance); err != nil {
			response(w, http.StatusInternalServerError, H{"error": err.Error()})
			return
		}

		if instance.ShadowsocksURL != nil && *instance.ShadowsocksURL != "" {
			urls = append(urls, *instance.ShadowsocksURL)
		}
		if instance.HysteriaURL != nil && *instance.HysteriaURL != "" {
			urls = append(urls, *instance.HysteriaURL)
		}
		if instance.XrayURL != nil && *instance.XrayURL != "" {
			urls = append(urls, *instance.XrayURL)
		}
	}

	// Shadowrocket-compatible subscription: base64 encoded, one URL per line
	plainText := []byte{}
	for i, u := range urls {
		if i > 0 {
			plainText = append(plainText, '\n')
		}
		plainText = append(plainText, []byte(u)...)
	}
	encoded := base64.StdEncoding.EncodeToString(plainText)

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, encoded)
}
