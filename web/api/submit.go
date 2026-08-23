package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type SubmitRequest struct {
	AuthToken         string            `json:"auth_token"`
	CombinedInstances []*InstanceConfig `json:"combined_instances"`
}

func validateInstances(instances []*InstanceConfig) error {
	for idx, instance := range instances {
		if instance == nil {
			continue
		}

		instanceName := instance.InstanceName
		if instanceName == "" {
			instanceName = fmt.Sprintf("#%d", idx+1)
		}

		if !instance.ShadowsocksEnable && !instance.HysteriaEnable && !instance.XrayEnable && !instance.AnyTLSEnable && !instance.TUICEnable {
			return fmt.Errorf("instance %s should enable at least one protocol", instanceName)
		}

		usedPorts := map[int]string{}
		if instance.ShadowsocksEnable {
			if protocol, exists := usedPorts[instance.ShadowsocksLibevPort]; exists {
				return fmt.Errorf("instance %s has port conflict: %d between %s and shadowsocks", instanceName, instance.ShadowsocksLibevPort, protocol)
			}
			usedPorts[instance.ShadowsocksLibevPort] = "shadowsocks"
		}

		if instance.HysteriaEnable {
			hPort := instance.HysteriaPort
			if hPort == 0 {
				hPort = 443
			}
			if protocol, exists := usedPorts[hPort]; exists {
				return fmt.Errorf("instance %s has port conflict: %d between %s and hysteria", instanceName, hPort, protocol)
			}
			usedPorts[hPort] = "hysteria"
		}

		if instance.XrayEnable {
			if protocol, exists := usedPorts[instance.XrayPort]; exists {
				return fmt.Errorf("instance %s has port conflict: %d between %s and xray", instanceName, instance.XrayPort, protocol)
			}
			usedPorts[instance.XrayPort] = "xray"
		}

		if instance.AnyTLSEnable {
			aPort := instance.AnyTLSPort
			if aPort == 0 {
				aPort = 8444
			}
			if protocol, exists := usedPorts[aPort]; exists {
				return fmt.Errorf("instance %s has port conflict: %d between %s and anytls", instanceName, aPort, protocol)
			}
			usedPorts[aPort] = "anytls"
		}

		if instance.TUICEnable {
			tPort := instance.TUICPort
			if tPort == 0 {
				tPort = 8445
			}
			if protocol, exists := usedPorts[tPort]; exists {
				return fmt.Errorf("instance %s has port conflict: %d between %s and tuic", instanceName, tPort, protocol)
			}
			usedPorts[tPort] = "tuic"
		}
	}

	return nil
}

func SubmitHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		response(w, http.StatusBadRequest, H{"error": "invalid http method"})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		response(w, http.StatusInternalServerError, H{"error": err.Error()})
		return
	}

	var req SubmitRequest
	if err := json.Unmarshal(body, &req); err != nil {
		response(w, http.StatusInternalServerError, H{"error": err.Error()})
		return
	}
	authToken := os.Getenv("AUTH_TOKEN")
	if req.AuthToken != authToken {
		response(w, http.StatusForbidden, H{"error": "invalid auth token"})
		return
	}

	if err := validateInstances(req.CombinedInstances); err != nil {
		response(w, http.StatusBadRequest, H{"error": err.Error()})
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

	instanceConfigList := InstanceConfigList{
		ShadowsocksInstances: make([]*ShadowsocksInstanceConfig, 0),
		HysteriaInstances:    make([]*HysteriaInstanceConfig, 0),
		CombinedInstances:    req.CombinedInstances,
		XrayInstances:        make([]*XrayInstanceConfig, 0),
		AnyTLSInstances:      make([]*AnyTLSInstanceConfig, 0),
		TUICInstances:        make([]*TUICInstanceConfig, 0),
	}
	instancesBytes, err := json.Marshal(instanceConfigList)
	if err != nil {
		response(w, http.StatusInternalServerError, H{"error": err.Error()})
		return
	}
	instancesReader := bytes.NewReader(instancesBytes)
	if err := bucket.PutObject(inputObjectKey, instancesReader); err != nil {
		response(w, http.StatusInternalServerError, H{"error": err.Error()})
		return
	}

	githubAccessToken := os.Getenv("GITHUB_ACCESS_TOKEN")
	githubRepository := os.Getenv("GITHUB_REPOSITORY")
	if err := sendGithubWorkflowDispatchRequest(githubAccessToken, githubRepository); err != nil {
		response(w, http.StatusInternalServerError, H{"error": err.Error()})
		return
	}

	response(w, http.StatusOK, H{"success": true})
}

func sendGithubWorkflowDispatchRequest(accessToken, repository string) error {
	repositoryURL := fmt.Sprintf("https://api.github.com/repos/%s/dispatches", repository)

	jsonBody := []byte(`{"event_type": "deploy-instances"}`)
	bodyReader := bytes.NewReader(jsonBody)
	req, err := http.NewRequest(http.MethodPost, repositoryURL, bodyReader)
	if err != nil {
		return err
	}
	req.Header.Add("Accept", "application/vnd.github+json")
	req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", accessToken))

	client := http.Client{
		Timeout: 30 * time.Second,
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	if resp.StatusCode == http.StatusNoContent {
		return nil
	} else {
		return fmt.Errorf("github response status code %d", resp.StatusCode)
	}
}
