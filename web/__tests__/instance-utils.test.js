import { describe, it, expect } from 'vitest'
import {
  defaultInstanceConfig,
  normalizeInstanceConfig,
  validateInstanceConfig,
} from '@/lib/instance-utils'

describe('normalizeInstanceConfig', () => {
  it('fills defaults when instance is null', () => {
    const result = normalizeInstanceConfig(null)
    expect(result).toEqual(defaultInstanceConfig)
  })

  it('fills defaults when instance is empty', () => {
    const result = normalizeInstanceConfig({})
    expect(result).toEqual(defaultInstanceConfig)
  })

  it('overrides default with provided values', () => {
    const result = normalizeInstanceConfig({
      instance_name: 'my-server',
      region: 'us-west-2',
    })
    expect(result.instance_name).toBe('my-server')
    expect(result.region).toBe('us-west-2')
    // availability_zone should be corrected to match us-west-2
    expect(result.availability_zone).toBe('us-west-2a')
  })

  it('fixes availability_zone when it does not match region', () => {
    const result = normalizeInstanceConfig({
      region: 'us-east-2',
      availability_zone: 'ap-northeast-1a',
    })
    expect(result.region).toBe('us-east-2')
    expect(result.availability_zone).toBe('us-east-2a')
  })

  it('generates availability_zone from region when unknown region', () => {
    const result = normalizeInstanceConfig({
      region: 'me-central-1',
      availability_zone: '',
    })
    expect(result.availability_zone).toBe('me-central-1a')
  })

  it('keeps valid availability_zone', () => {
    const result = normalizeInstanceConfig({
      region: 'ap-northeast-1',
      availability_zone: 'ap-northeast-1c',
    })
    expect(result.availability_zone).toBe('ap-northeast-1c')
  })

  it('normalizes zero or empty protocol fields to defaults', () => {
    const result = normalizeInstanceConfig({
      anytls_port: 0,
      anytls_password_length: 0,
      anytls_proxy_url: '',
      tuic_port: 0,
      tuic_password_length: 0,
      tuic_proxy_url: '',
    })
    expect(result.anytls_port).toBe(8444)
    expect(result.anytls_password_length).toBe(10)
    expect(result.anytls_proxy_url).toBe('https://bing.com')
    expect(result.tuic_port).toBe(8445)
    expect(result.tuic_password_length).toBe(10)
    expect(result.tuic_proxy_url).toBe('https://bing.com')
  })
})

describe('validateInstanceConfig', () => {
  function validConfig(overrides = {}) {
    return { ...defaultInstanceConfig, ...overrides }
  }

  it('returns null for valid config', () => {
    expect(validateInstanceConfig(validConfig(), 0)).toBeNull()
  })

  it('rejects config with no protocol enabled', () => {
    const cfg = validConfig({
      shadowsocks_enable: false,
      hysteria_enable: false,
      xray_enable: false,
      anytls_enable: false,
      tuic_enable: false,
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('至少开启一个协议')
  })

  it('rejects empty region', () => {
    const cfg = validConfig({ region: '' })
    expect(validateInstanceConfig(cfg, 0)).toContain('region 不能为空')
  })

  it('rejects empty availability_zone', () => {
    const cfg = validConfig({ availability_zone: '' })
    expect(validateInstanceConfig(cfg, 0)).toContain('availability_zone 不能为空')
  })

  it('rejects invalid hysteria_proxy_url', () => {
    const cfg = validConfig({
      hysteria_enable: true,
      hysteria_proxy_url: 'ftp://bad.url',
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('hysteria_proxy_url')
  })

  it('accepts valid hysteria_proxy_url', () => {
    const cfg = validConfig({
      hysteria_enable: true,
      hysteria_proxy_url: 'https://example.com',
    })
    expect(validateInstanceConfig(cfg, 0)).toBeNull()
  })

  it('rejects invalid xray_proxy_url', () => {
    const cfg = validConfig({
      xray_enable: true,
      xray_private_key: 'pk',
      xray_public_key: 'pubk',
      xray_proxy_url: 'invalid',
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('xray_proxy_url')
  })

  it('rejects xray without keys', () => {
    const cfg = validConfig({
      xray_enable: true,
      xray_private_key: '',
      xray_public_key: '',
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('xray_private_key')
  })

  it('rejects invalid anytls_proxy_url', () => {
    const cfg = validConfig({
      anytls_enable: true,
      anytls_proxy_url: 'invalid-url',
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('anytls_proxy_url')
  })

  it('rejects invalid tuic_proxy_url', () => {
    const cfg = validConfig({
      tuic_enable: true,
      tuic_proxy_url: 'invalid-url',
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('tuic_proxy_url')
  })

  it('rejects port conflict: ss port equals hysteria port', () => {
    const cfg = validConfig({
      shadowsocks_enable: true,
      hysteria_enable: true,
      shadowsocks_libev_port: 8443,
      hysteria_port: 8443,
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('端口冲突')
    expect(validateInstanceConfig(cfg, 0)).toContain('8443')
  })

  it('rejects port conflict: xray port equals hysteria port', () => {
    const cfg = validConfig({
      xray_enable: true,
      hysteria_enable: true,
      xray_port: 8443,
      hysteria_port: 8443,
      xray_private_key: 'pk',
      xray_public_key: 'pubk',
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('端口冲突')
  })

  it('rejects port conflict: ss port equals xray port', () => {
    const cfg = validConfig({
      shadowsocks_enable: true,
      xray_enable: true,
      shadowsocks_libev_port: 9000,
      xray_port: 9000,
      xray_private_key: 'pk',
      xray_public_key: 'pubk',
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('端口冲突')
  })

  it('rejects port conflict: anytls port equals hysteria port', () => {
    const cfg = validConfig({
      anytls_enable: true,
      hysteria_enable: true,
      anytls_port: 8443,
      hysteria_port: 8443,
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('端口冲突')
  })

  it('rejects port conflict: tuic port equals anytls port', () => {
    const cfg = validConfig({
      tuic_enable: true,
      anytls_enable: true,
      tuic_port: 8444,
      anytls_port: 8444,
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('端口冲突')
  })

  it('uses instance_name in error message', () => {
    const cfg = validConfig({
      instance_name: 'my-server',
      region: '',
    })
    expect(validateInstanceConfig(cfg, 0)).toContain('my-server')
  })

  it('falls back to index-based name when instance_name is empty', () => {
    const cfg = validConfig({
      instance_name: '',
      region: '',
    })
    expect(validateInstanceConfig(cfg, 2)).toContain('#3')
  })
})
