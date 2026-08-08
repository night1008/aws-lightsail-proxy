package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/aliyun/aliyun-oss-go-sdk/oss"
)

var httpClient = &http.Client{
	Timeout: 10 * time.Second,
}
var userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
var (
	streamIDPattern = regexp.MustCompile(`stream_id\s*?=\s*?'(\d+)'`)
	cookiePattern   = regexp.MustCompile(`document.cookie="(.*?)"`)
)

var endpoint, accessKeyID, accessKeySecret, bucketName string

func init() {
	flag.StringVar(&endpoint, "endpoint", "oss-cn-hangzhou.aliyuncs.com", "oss endpoint")
	flag.StringVar(&accessKeyID, "access-key-id", "key", "oss access key id")
	flag.StringVar(&accessKeySecret, "access-key-secret", "secret", "oss access key secret")
	flag.StringVar(&bucketName, "bucket", "aws-lightsail-terraform", "oss bucket name")
}

func main() {
	flag.Parse()

	addrs, err := readPingAddrsFromOss(endpoint, accessKeyID, accessKeySecret, bucketName)
	if err != nil {
		panic(err)
	}
	for _, addr := range addrs {
		tcpStr := fmt.Sprintf("%s:%d", addr.StaticIP, addr.ShadowsocksConfig.ServerPort)
		success, err := checkTcpPing(tcpStr)
		if err != nil {
			panic(err)
		}
		var status string
		if success {
			status = "avaiable"
		} else {
			status = "blocked"
		}
		fmt.Printf("instance_name: %s, addr: %s is %s.\nshadowsocks_url: %s\n",
			addr.InstanceName, tcpStr, status, addr.ShadowsocksURL)
	}
}

type PingAddr struct {
	InstanceName      string `json:"instance_name"`
	PublicIPAddress   string `json:"public_ip_address"`
	ShadowsocksConfig struct {
		LocalPort  int      `json:"local_port"`
		Method     string   `json:"method"`
		Mode       string   `json:"mode"`
		Password   string   `json:"password"`
		Server     []string `json:"server"`
		ServerPort int      `json:"server_port"`
		Timeout    int      `json:"timeout"`
	} `json:"shadowsocks_config"`
	ShadowsocksURL string `json:"shadowsocks_url"`
	StaticIP       string `json:"static_ip"`
}

func readPingAddrsFromOss(endpoint, accessKeyID, accessKeySecret, bucketName string) ([]*PingAddr, error) {
	ossClient, err := oss.New(endpoint, accessKeyID, accessKeySecret)
	if err != nil {
		return nil, err
	}

	bucket, err := ossClient.Bucket(bucketName)
	if err != nil {
		return nil, err
	}

	objectsResult, err := bucket.ListObjects()
	if err != nil {
		return nil, err
	}

	pingAddrs := make([]*PingAddr, 0)
	outputPrefix := "outputs/"
	for _, object := range objectsResult.Objects {
		if !strings.HasPrefix(object.Key, outputPrefix) {
			continue
		}
		body, err := bucket.GetObject(object.Key)
		if err != nil {
			return nil, err
		}

		defer body.Close()
		var buf bytes.Buffer
		if _, err := io.Copy(&buf, body); err != nil {
			return nil, err
		}
		var pingAddr PingAddr
		if err := json.Unmarshal(buf.Bytes(), &pingAddr); err != nil {
			return nil, err
		}
		pingAddrs = append(pingAddrs, &pingAddr)
	}
	return pingAddrs, nil
}

func checkTcpPing(tcpStr string) (bool, error) {
	cookie, err := getCookie()
	if err != nil {
		return false, err
	}

	streamID, err := getStreamID(tcpStr, cookie)
	if err != nil {
		return false, err
	}

	result, err := waitForAllPingResults(tcpStr, streamID, cookie)
	if err != nil {
		return false, err
	}

	success := checkChinaPingSuccess(result)
	return success, nil
}

// 拿到 cookie
func getCookie() (string, error) {
	url := "https://tcp.ping.pe"
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	cookies := cookiePattern.FindAllStringSubmatch(string(body), -1)
	var cookie string
	if len(cookies) > 0 {
		cookie = cookies[0][1]
	}
	return cookie, nil
}

// 拿到 stream_id
func getStreamID(tcpStr, cookie string) (string, error) {
	url := fmt.Sprintf("https://tcp.ping.pe/%s", tcpStr)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}
	req.Header = http.Header{
		"user-agent": {userAgent},
		"cookie":     {cookie},
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	streamIDs := streamIDPattern.FindAllStringSubmatch(string(body), -1)
	var streamID string
	if len(streamIDs) > 0 {
		streamID = streamIDs[0][1]
	}
	return streamID, nil
}

type PingResult struct {
	Data []struct {
		NodeID      string `json:"node_id"`
		TimestampMS int64  `json:"timestamp_ms"`
		Result      int    `json:"result"`
		ResultText  string `json:"result_text"`
	} `json:"data"`
	State struct {
		OutstandingNodeCount int `json:"outstandingNodeCount"`
	} `json:"state"`
}

// 异步请求检测结果
func getPingResults(tcpStr, streamID, cookie string) (*PingResult, error) {
	url := fmt.Sprintf("https://tcp.ping.pe/ajax_getPingResults_v2.php?stream_id=%s", streamID)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header = http.Header{
		"user-agent": {userAgent},
		"referer":    {fmt.Sprintf("https://tcp.ping.pe/%s", tcpStr)},
		"cookie":     {cookie},
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	var result PingResult
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// 等待所有区域的检测结果
func waitForAllPingResults(tcpStr, streamID, cookie string) (*PingResult, error) {
	var maxPingResultRequestCount = 20 // 最大重试次数
	var result PingResult
	for i := 0; i < maxPingResultRequestCount; i++ {
		_result, err := getPingResults(tcpStr, streamID, cookie)
		if err != nil {
			return nil, err
		}
		result.Data = append(result.Data, _result.Data...)
		result.State.OutstandingNodeCount = _result.State.OutstandingNodeCount
		if result.State.OutstandingNodeCount == 0 {
			break
		}
		time.Sleep(time.Second)
	}
	if result.State.OutstandingNodeCount != 0 {
		return nil, fmt.Errorf("exceed max request count: %d", maxPingResultRequestCount)
	}
	return &result, nil
}

// 暂定可用策略为：可用数量 > 失败数量
func checkChinaPingSuccess(result *PingResult) bool {
	chinaNodeIDPrefix := "CN_"
	var successCount, failCount int
	for _, node := range result.Data {
		if !strings.HasPrefix(node.NodeID, chinaNodeIDPrefix) {
			continue
		}
		if node.Result == 0 {
			successCount += 1
		} else {
			failCount += 1
		}
	}
	return successCount > failCount
}
