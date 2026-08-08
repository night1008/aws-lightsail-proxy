import { describe, it, expect } from 'vitest'
import { mockInput, mockSubmit } from '@/lib/mocks/api'
import { createMocks } from 'node-mocks-http'

describe('mockInput', () => {
  it('returns 403 when no auth_token', () => {
    const { req, res } = createMocks({ method: 'GET', query: {} })
    mockInput(req, res)
    expect(res._getStatusCode()).toBe(403)
    expect(res._getJSONData()).toEqual({ error: 'auth_token required' })
  })

  it('returns mock data with combined_instances', () => {
    const { req, res } = createMocks({
      method: 'GET',
      query: { auth_token: 'test' },
    })
    mockInput(req, res)
    expect(res._getStatusCode()).toBe(200)
    const data = res._getJSONData()
    expect(data.combined_instances).toHaveLength(2)
    expect(data.combined_instances[0].instance_name).toBe('tokyo-ss')
    expect(data.combined_instances[1].instance_name).toBe('oregon-xray')
  })

  it('first instance has ss and hysteria enabled', () => {
    const { req, res } = createMocks({
      method: 'GET',
      query: { auth_token: 'test' },
    })
    mockInput(req, res)
    const inst = res._getJSONData().combined_instances[0]
    expect(inst.shadowsocks_enable).toBe(true)
    expect(inst.hysteria_enable).toBe(true)
    expect(inst.xray_enable).toBe(false)
  })

  it('second instance has ss and xray enabled', () => {
    const { req, res } = createMocks({
      method: 'GET',
      query: { auth_token: 'test' },
    })
    mockInput(req, res)
    const inst = res._getJSONData().combined_instances[1]
    expect(inst.shadowsocks_enable).toBe(true)
    expect(inst.xray_enable).toBe(true)
    expect(inst.hysteria_enable).toBe(false)
    expect(inst.xray_private_key).toBeTruthy()
    expect(inst.xray_public_key).toBeTruthy()
  })
})

describe('mockSubmit', () => {
  it('returns 405 for non-POST', () => {
    const { req, res } = createMocks({ method: 'GET' })
    mockSubmit(req, res)
    expect(res._getStatusCode()).toBe(405)
  })

  it('returns 403 when no auth_token', () => {
    const { req, res } = createMocks({
      method: 'POST',
      body: {},
    })
    mockSubmit(req, res)
    expect(res._getStatusCode()).toBe(403)
  })

  it('returns success with instance count', () => {
    const { req, res } = createMocks({
      method: 'POST',
      body: {
        auth_token: 'test',
        combined_instances: [{}, {}, {}],
      },
    })
    mockSubmit(req, res)
    expect(res._getStatusCode()).toBe(200)
    expect(res._getJSONData()).toEqual({ success: true, instances: 3 })
  })

  it('handles empty instances', () => {
    const { req, res } = createMocks({
      method: 'POST',
      body: {
        auth_token: 'test',
        combined_instances: [],
      },
    })
    mockSubmit(req, res)
    expect(res._getStatusCode()).toBe(200)
    expect(res._getJSONData().instances).toBe(0)
  })
})
