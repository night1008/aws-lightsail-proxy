import { lightsail_availability_zones } from '@/lib/regions'

export const defaultInstanceConfig = {
  region: 'ap-northeast-1',
  instance_name: 'instance-1',
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
}

export function normalizeInstanceConfig(instance) {
  const config = {
    ...defaultInstanceConfig,
    ...(instance || {}),
  }

  const regionZones = lightsail_availability_zones[config.region]
  if (regionZones && regionZones.length > 0) {
    const hasAvailabilityZone = regionZones.some(
      (zone) => zone.value === config.availability_zone,
    )
    if (!hasAvailabilityZone) {
      config.availability_zone = regionZones[0].value
    }
  } else if (!config.availability_zone && config.region) {
    config.availability_zone = config.region + 'a'
  }

  return config
}

export function validateInstanceConfig(instance, index) {
  const name = instance.instance_name || `#${index + 1}`

  if (
    !instance.shadowsocks_enable &&
    !instance.hysteria_enable &&
    !instance.xray_enable &&
    !instance.anytls_enable &&
    !instance.tuic_enable
  ) {
    return `实例 ${name} 至少开启一个协议`
  }

  if (!instance.region) {
    return `实例 ${name} region 不能为空`
  }

  if (!instance.availability_zone) {
    return `实例 ${name} availability_zone 不能为空`
  }

  if (instance.hysteria_enable) {
    if (!/^https?:\/\//.test(instance.hysteria_proxy_url)) {
      return `实例 ${name} hysteria_proxy_url 必须是有效的 http(s) URL`
    }
  }

  if (instance.xray_enable) {
    if (!/^https?:\/\//.test(instance.xray_proxy_url)) {
      return `实例 ${name} xray_proxy_url 必须是有效的 http(s) URL`
    }
    if (!instance.xray_private_key || !instance.xray_public_key) {
      return `实例 ${name} 启用 xray 时必须提供 xray_private_key 和 xray_public_key`
    }
  }

  if (instance.anytls_enable) {
    if (!/^https?:\/\//.test(instance.anytls_proxy_url)) {
      return `实例 ${name} anytls_proxy_url 必须是有效的 http(s) URL`
    }
  }

  if (instance.tuic_enable) {
    if (!/^https?:\/\//.test(instance.tuic_proxy_url)) {
      return `实例 ${name} tuic_proxy_url 必须是有效的 http(s) URL`
    }
  }

  const usedPorts = {}
  if (instance.shadowsocks_enable) {
    usedPorts[instance.shadowsocks_libev_port] = 'shadowsocks'
  }
  if (instance.hysteria_enable) {
    const hPort = instance.hysteria_port || 8443
    if (usedPorts[hPort]) {
      return `实例 ${name} 端口冲突: hysteria2 端口 (${hPort}) 与 ${usedPorts[hPort]} 不能使用相同端口`
    }
    usedPorts[hPort] = 'hysteria2'
  }
  if (instance.xray_enable) {
    const xPort = instance.xray_port
    if (usedPorts[xPort]) {
      return `实例 ${name} 端口冲突: xray 端口 (${xPort}) 与 ${usedPorts[xPort]} 不能使用相同端口`
    }
    usedPorts[xPort] = 'xray'
  }
  if (instance.anytls_enable) {
    const aPort = instance.anytls_port || 8444
    if (usedPorts[aPort]) {
      return `实例 ${name} 端口冲突: anytls 端口 (${aPort}) 与 ${usedPorts[aPort]} 不能使用相同端口`
    }
    usedPorts[aPort] = 'anytls'
  }
  if (instance.tuic_enable) {
    const tPort = instance.tuic_port || 8445
    if (usedPorts[tPort]) {
      return `实例 ${name} 端口冲突: tuic 端口 (${tPort}) 与 ${usedPorts[tPort]} 不能使用相同端口`
    }
    usedPorts[tPort] = 'tuic'
  }

  return null
}
