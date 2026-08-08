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
    !instance.xray_enable
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

  const hysteriaPort = instance.hysteria_port || 8443

  if (instance.hysteria_enable) {
    if (
      instance.shadowsocks_enable &&
      instance.shadowsocks_libev_port === hysteriaPort
    ) {
      return `实例 ${name} 端口冲突: hysteria2 端口 (${hysteriaPort})，shadowsocks_libev_port 不能使用相同端口`
    }
    if (instance.xray_enable && instance.xray_port === hysteriaPort) {
      return `实例 ${name} 端口冲突: hysteria2 端口 (${hysteriaPort})，xray_port 不能使用相同端口`
    }
  }

  if (instance.shadowsocks_enable && instance.xray_enable) {
    if (instance.shadowsocks_libev_port === instance.xray_port) {
      return `实例 ${name} 端口冲突: shadowsocks_libev_port (${instance.shadowsocks_libev_port}) 与 xray_port 不能相同`
    }
  }

  return null
}
