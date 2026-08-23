package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"

	"github.com/aliyun/aliyun-oss-go-sdk/oss"
)

const (
	contentTypeKey   = "Content-Type"
	contentTypeValue = "application/json; charset=utf-8"
)

type H map[string]interface{}

func response(w http.ResponseWriter, statusCode int, data interface{}) {
	w.Header().Set(contentTypeKey, contentTypeValue)

	dataBytes, err := json.Marshal(data)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(err.Error()))
	} else {
		w.WriteHeader(statusCode)
		w.Write(dataBytes)
	}
}

func getOSSClient(region, accessKey, accessKeySecret string) (*oss.Client, error) {
	endpoint := fmt.Sprintf("https://oss-%s.aliyuncs.com", region)
	return oss.New(endpoint, accessKey, accessKeySecret)
}

const (
	inputObjectKey = "inputs/terraform.tfvars.json"
)

var ossObjectNotExistPattern = regexp.MustCompile("(StatusCode=404|ErrorCode=NoSuchKey)")

type InstanceConfig struct {
	Region                         string `json:"region"`
	InstanceName                   string `json:"instance_name"`
	AvailabilityZone               string `json:"availability_zone"`
	CreateStaticIP                 bool   `json:"create_static_ip"`
	ShadowsocksEnable              bool   `json:"shadowsocks_enable"`
	ShadowsocksLibevPort           int    `json:"shadowsocks_libev_port"`
	ShadowsocksLibevPasswordLength int    `json:"shadowsocks_libev_password_length"`
	ShadowsocksLibevMethod         string `json:"shadowsocks_libev_method"`
	HysteriaEnable                 bool   `json:"hysteria_enable"`
	HysteriaPort                   int    `json:"hysteria_port"`
	HysteriaPasswordLength         int    `json:"hysteria_password_length"`
	HysteriaProxyURL               string `json:"hysteria_proxy_url"`
	XrayEnable                     bool   `json:"xray_enable"`
	XrayPort                       int    `json:"xray_port"`
	XrayProxyURL                   string `json:"xray_proxy_url"`
	XrayPrivateKey                 string `json:"xray_private_key"`
	XrayPublicKey                  string `json:"xray_public_key"`
	AnyTLSEnable                   bool   `json:"anytls_enable"`
	AnyTLSPort                     int    `json:"anytls_port"`
	AnyTLSPasswordLength           int    `json:"anytls_password_length"`
	AnyTLSProxyURL                 string `json:"anytls_proxy_url"`
	TUICEnable                     bool   `json:"tuic_enable"`
	TUICPort                       int    `json:"tuic_port"`
	TUICPasswordLength             int    `json:"tuic_password_length"`
	TUICProxyURL                   string `json:"tuic_proxy_url"`
}

type ShadowsocksInstanceConfig struct {
	Region                         string `json:"region"`
	InstanceName                   string `json:"instance_name"`
	AvailabilityZone               string `json:"availability_zone"`
	CreateStaticIP                 bool   `json:"create_static_ip"`
	ShadowsocksLibevPort           int    `json:"shadowsocks_libev_port"`
	ShadowsocksLibevPasswordLength int    `json:"shadowsocks_libev_password_length"`
	ShadowsocksLibevMethod         string `json:"shadowsocks_libev_method"`
}

type HysteriaInstanceConfig struct {
	Region                 string `json:"region"`
	InstanceName           string `json:"instance_name"`
	AvailabilityZone       string `json:"availability_zone"`
	CreateStaticIP         bool   `json:"create_static_ip"`
	HysteriaPort           int    `json:"hysteria_port"`
	HysteriaPasswordLength int    `json:"hysteria_password_length"`
	HysteriaProxyURL       string `json:"hysteria_proxy_url"`
}

type XrayInstanceConfig struct {
	Region           string `json:"region"`
	InstanceName     string `json:"instance_name"`
	AvailabilityZone string `json:"availability_zone"`
	CreateStaticIP   bool   `json:"create_static_ip"`
	XrayPort         int    `json:"xray_port"`
	XrayProxyURL     string `json:"xray_proxy_url"`
	XrayPrivateKey   string `json:"xray_private_key"`
	XrayPublicKey    string `json:"xray_public_key"`
}

type AnyTLSInstanceConfig struct {
	Region                 string `json:"region"`
	InstanceName           string `json:"instance_name"`
	AvailabilityZone       string `json:"availability_zone"`
	CreateStaticIP         bool   `json:"create_static_ip"`
	AnyTLSPort             int    `json:"anytls_port"`
	AnyTLSPasswordLength   int    `json:"anytls_password_length"`
	AnyTLSProxyURL         string `json:"anytls_proxy_url"`
}

type TUICInstanceConfig struct {
	Region               string `json:"region"`
	InstanceName         string `json:"instance_name"`
	AvailabilityZone     string `json:"availability_zone"`
	CreateStaticIP       bool   `json:"create_static_ip"`
	TUICPort             int    `json:"tuic_port"`
	TUICPasswordLength   int    `json:"tuic_password_length"`
	TUICProxyURL         string `json:"tuic_proxy_url"`
}

type InstanceConfigList struct {
	ShadowsocksInstances []*ShadowsocksInstanceConfig `json:"shadowsocks_instances"`
	HysteriaInstances    []*HysteriaInstanceConfig    `json:"hysteria_instances"`
	CombinedInstances    []*InstanceConfig            `json:"combined_instances"`
	XrayInstances        []*XrayInstanceConfig        `json:"xray_instances"`
	AnyTLSInstances      []*AnyTLSInstanceConfig      `json:"anytls_instances"`
	TUICInstances        []*TUICInstanceConfig        `json:"tuic_instances"`
}

func InputHandler(w http.ResponseWriter, r *http.Request) {
	authToken := os.Getenv("AUTH_TOKEN")
	if r.URL.Query().Get("auth_token") != authToken {
		response(w, http.StatusForbidden, H{"error": "invalid auth token"})
		return
	}

	region := os.Getenv("ALICLOUD_REGION")
	accessKey := os.Getenv("ALICLOUD_ACCESS_KEY")
	accessKeySecret := os.Getenv("ALICLOUD_SECRET_KEY")
	bucketName := os.Getenv("ALICLOUD_BUCKET")

	client, err := getOSSClient(region, accessKey, accessKeySecret)
	if err != nil {
		response(w, http.StatusInternalServerError, H{"error": "failed to connect to storage"})
		return
	}

	bucket, err := client.Bucket(bucketName)
	if err != nil {
		response(w, http.StatusInternalServerError, H{"error": "failed to access storage bucket"})
		return
	}

	var instanceConfigList InstanceConfigList
	object, err := bucket.GetObject(inputObjectKey)
	if err != nil {
		if ossObjectNotExistPattern.MatchString(err.Error()) {
			instanceConfigList.ShadowsocksInstances = make([]*ShadowsocksInstanceConfig, 0)
			instanceConfigList.HysteriaInstances = make([]*HysteriaInstanceConfig, 0)
			instanceConfigList.CombinedInstances = make([]*InstanceConfig, 0)
			instanceConfigList.XrayInstances = make([]*XrayInstanceConfig, 0)
			instanceConfigList.AnyTLSInstances = make([]*AnyTLSInstanceConfig, 0)
			instanceConfigList.TUICInstances = make([]*TUICInstanceConfig, 0)
			response(w, http.StatusOK, instanceConfigList)
		} else {
			response(w, http.StatusInternalServerError, H{"error": "failed to read configuration"})
		}
		return
	}

	defer object.Close()
	body, err := io.ReadAll(object)
	if err != nil {
		response(w, http.StatusInternalServerError, H{"error": "failed to read configuration data"})
		return
	}
	if err := json.Unmarshal(body, &instanceConfigList); err != nil {
		response(w, http.StatusInternalServerError, H{"error": "failed to parse configuration"})
		return
	}

	if instanceConfigList.ShadowsocksInstances == nil {
		instanceConfigList.ShadowsocksInstances = make([]*ShadowsocksInstanceConfig, 0)
	}
	if instanceConfigList.HysteriaInstances == nil {
		instanceConfigList.HysteriaInstances = make([]*HysteriaInstanceConfig, 0)
	}
	if instanceConfigList.CombinedInstances == nil {
		instanceConfigList.CombinedInstances = make([]*InstanceConfig, 0)
	}
	if instanceConfigList.XrayInstances == nil {
		instanceConfigList.XrayInstances = make([]*XrayInstanceConfig, 0)
	}
	if instanceConfigList.AnyTLSInstances == nil {
		instanceConfigList.AnyTLSInstances = make([]*AnyTLSInstanceConfig, 0)
	}
	if instanceConfigList.TUICInstances == nil {
		instanceConfigList.TUICInstances = make([]*TUICInstanceConfig, 0)
	}

	response(w, http.StatusOK, instanceConfigList)
}
