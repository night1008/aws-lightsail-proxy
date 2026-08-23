// 本地开发 mock 数据，通过 next.config.js rewrites 注入
// 线上不受影响（api/*.go Go functions 处理真实请求）

export function mockInput(req, res) {
  const { auth_token } = req.query
  if (!auth_token) {
    return res.status(403).json({ error: 'auth_token required' })
  }
  res.status(200).json({
    combined_instances: [
      {
        region: 'ap-northeast-1',
        instance_name: 'tokyo-ss',
        availability_zone: 'ap-northeast-1a',
        create_static_ip: true,
        shadowsocks_enable: true,
        shadowsocks_libev_port: 8388,
        shadowsocks_libev_password_length: 10,
        shadowsocks_libev_method: 'chacha20-ietf-poly1305',
        hysteria_enable: true,
        hysteria_port: 8443,
        hysteria_password_length: 10,
        hysteria_proxy_url: 'https://bing.com',
        xray_enable: false,
        xray_port: 443,
        xray_proxy_url: 'https://bing.com',
        xray_private_key: '',
        xray_public_key: '',
        anytls_enable: false,
        anytls_port: 8444,
        anytls_password_length: 10,
        anytls_proxy_url: 'https://bing.com',
        tuic_enable: false,
        tuic_port: 8445,
        tuic_password_length: 10,
        tuic_proxy_url: 'https://bing.com',
      },
      {
        region: 'us-west-2',
        instance_name: 'oregon-xray',
        availability_zone: 'us-west-2a',
        create_static_ip: false,
        shadowsocks_enable: true,
        shadowsocks_libev_port: 9000,
        shadowsocks_libev_password_length: 16,
        shadowsocks_libev_method: 'aes-256-gcm',
        hysteria_enable: false,
        hysteria_port: 8443,
        hysteria_password_length: 10,
        hysteria_proxy_url: 'https://bing.com',
        xray_enable: true,
        xray_port: 443,
        xray_proxy_url: 'https://bing.com',
        xray_private_key: 'mock-private-key-xxxx',
        xray_public_key: 'mock-public-key-yyyy',
        anytls_enable: true,
        anytls_port: 8444,
        anytls_password_length: 16,
        anytls_proxy_url: 'https://bing.com',
        tuic_enable: true,
        tuic_port: 8445,
        tuic_password_length: 16,
        tuic_proxy_url: 'https://bing.com',
      },
    ],
  })
}

export function mockSubmit(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' })
  }
  const { auth_token, combined_instances } = req.body
  if (!auth_token) {
    return res.status(403).json({ error: 'auth_token required' })
  }
  console.log('[mock submit] received', combined_instances?.length, 'instances')
  res.status(200).json({ success: true, instances: combined_instances?.length })
}
