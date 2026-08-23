import Head from 'next/head'
import { useEffect, useState, startTransition } from 'react'
import { Loader2, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { Alert, AlertDescription } from '@/components/ui/alert'
import {
  defaultInstanceConfig,
  normalizeInstanceConfig,
  validateInstanceConfig,
} from '@/lib/instance-utils'
import {
  lightsail_availability_zones,
  lightsail_regions,
  shadowsocks_libev_method_options,
} from '@/lib/regions'

export default function Home() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(false)
  const [editMode, setEditMode] = useState(false)
  const [instanceConfigs, setInstanceConfigs] = useState([])
  const [submitTime, setSubmitTime] = useState(0)
  const [authToken, setAuthToken] = useState('')
  const [formError, setFormError] = useState('')
  const [hydrated, setHydrated] = useState(false)
  const [needsAuth, setNeedsAuth] = useState(true)

  // 客户端挂载后从 localStorage 恢复状态
  useEffect(() => {
    startTransition(() => {
      const stored = localStorage.getItem('auth_token')
      if (stored) {
        setAuthToken(stored)
        setNeedsAuth(false)
      } else {
        setNeedsAuth(true)
      }
      setHydrated(true)
    })
  }, [])

  // auth_token 变化时持久化到 localStorage
  useEffect(() => {
    if (authToken) {
      localStorage.setItem('auth_token', authToken)
    } else {
      localStorage.removeItem('auth_token')
    }
  }, [authToken])

  useEffect(() => {
    if (!hydrated) return

    const token = localStorage.getItem('auth_token')
    if (!token) {
      return
    }

    startTransition(() => setLoading(true))
    fetch('/api/input?auth_token=' + encodeURIComponent(token))
      .then((res) => {
        if (res.status === 403) {
          // token 无效，清除并提示重新输入
          localStorage.removeItem('auth_token')
          setAuthToken('')
          setNeedsAuth(true)
          setLoading(false)
          return null
        }
        return res.json()
      })
      .then((data) => {
        if (!data) return
        const normalizedInstances = (data.combined_instances || []).map((instance) => normalizeInstanceConfig(instance))
        setData({
          ...data,
          combined_instances: normalizedInstances
        })
        setInstanceConfigs(normalizedInstances)
        setLoading(false)
      })
      .catch(() => {
        setLoading(false)
        setFormError('加载配置失败')
      })
  }, [submitTime, hydrated])

  function handleAuthSubmit(e) {
    e.preventDefault()
    if (!authToken) return
    localStorage.setItem('auth_token', authToken)
    setFormError('')
    setNeedsAuth(false)
    setSubmitTime(new Date().getTime())
  }

  function handleSubmitInstanceConfig(e) {
    e.preventDefault()
    e.stopPropagation()

    for (let i = 0; i < instanceConfigs.length; i++) {
      const err = validateInstanceConfig(instanceConfigs[i], i)
      if (err) {
        setFormError(err)
        return
      }
    }

    setFormError("")
    setLoading(true)
    fetch('/api/submit', {
      method: "POST",
      body: JSON.stringify({
        "auth_token": authToken,
        "combined_instances": instanceConfigs
      })
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.error) {
          setLoading(false)
          setFormError(data.error)
          return
        }
        setEditMode(false)
        setFormError("")
        setSubmitTime(new Date().getTime())
      })
      .catch(() => {
        setLoading(false)
        setFormError('提交失败')
      })
  }

  function handleAddInstanceConfig() {
    const configs = [...instanceConfigs]
    configs.push(Object.assign({}, defaultInstanceConfig, {
      instance_name: `instance-${configs.length + 1}`
    }))
    setInstanceConfigs(configs)
  }

  function handleRemoveInstanceConfig(index) {
    const configs = [...instanceConfigs]
    configs.splice(index, 1)
    setInstanceConfigs(configs)
  }

  function handleInstanceChange(index, attr, value) {
    const configs = [...instanceConfigs]
    configs[index][attr] = value
    if (attr === "region") {
      const zones = lightsail_availability_zones[value]
      if (zones && zones.length > 0) {
        configs[index]["availability_zone"] = zones[0].value
      } else {
        // region 不在前端 zone map 中时，根据 region 生成默认 availability_zone
        configs[index]["availability_zone"] = value + "a"
      }
    }
    setFormError("")
    setInstanceConfigs(configs)
  }

  function getRegionLabel(regionCode) {
    const region = lightsail_regions.find(r => r.value === regionCode)
    return region ? region.label : regionCode
  }

  return (
    <div className="min-h-screen bg-muted/30">
      <Head>
        <title>AWS Lightsail Proxy</title>
        <meta name="description" content="AWS Lightsail 代理节点管理" />
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <header className="border-b bg-background/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="container mx-auto max-w-5xl px-4 h-14 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-green-500" />
            <span className="font-semibold text-sm">AWS Lightsail Proxy</span>
          </div>
          {!loading && (
            <div className="flex items-center gap-2">
              <Label htmlFor="edit-mode" className="text-sm text-muted-foreground cursor-pointer">
                {editMode ? '关闭编辑' : '开启编辑'}
              </Label>
              <Switch
                id="edit-mode"
                checked={editMode}
                onCheckedChange={(checked) => setEditMode(checked)}
              />
            </div>
          )}
        </div>
      </header>

      <main className="container mx-auto max-w-5xl px-4 py-8">
        {(!hydrated || loading) && !editMode && (
          <div className="flex justify-center py-16">
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </div>
        )}

        {/* Auth 验证 */}
        {!loading && needsAuth && (
          <div className="flex flex-col items-center justify-center py-20 gap-4">
            <div className="text-4xl">🔐</div>
            <h2 className="text-lg font-semibold">需要验证</h2>
            <p className="text-sm text-muted-foreground">请输入 Auth Token 以加载配置</p>
            <form onSubmit={handleAuthSubmit} className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 w-full max-w-md">
              <Input
                type="password"
                placeholder="Auth Token"
                value={authToken}
                onChange={(e) => setAuthToken(e.target.value)}
                className="flex-1"
                autoFocus
              />
              <Button type="submit" className="flex-shrink-0">
                验证
              </Button>
            </form>
            {formError && (
              <Alert variant="destructive" className="max-w-md">
                <AlertDescription>{formError}</AlertDescription>
              </Alert>
            )}
          </div>
        )}

        {/* 查看模式 */}
        {!loading && !needsAuth && !editMode && (data?.combined_instances || []).length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {(data?.combined_instances || []).map((instance) => (
              <Card key={instance.instance_name} className="overflow-hidden">
                <CardHeader className="bg-muted/40 border-b">
                  <div className="flex items-center gap-2">
                    <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                    <span className="font-medium text-sm">{instance.instance_name}</span>
                    <span className="ml-auto text-xs text-muted-foreground">{getRegionLabel(instance.region)}</span>
                  </div>
                </CardHeader>
                <CardContent className="p-4 space-y-3">
                  <div className="grid grid-cols-2 gap-x-4 gap-y-1.5 text-sm">
                    <div className="text-muted-foreground">Region</div>
                    <div>{getRegionLabel(instance.region)}</div>
                    <div className="text-muted-foreground">可用区</div>
                    <div>{instance.availability_zone}</div>
                    <div className="text-muted-foreground">静态 IP</div>
                    <div>{instance.create_static_ip ? <span className="text-green-600 font-medium">✓ 启用</span> : <span className="text-muted-foreground">—</span>}</div>
                  </div>

                  <div className="border-t pt-3">
                    <div className="flex items-center gap-2 mb-2">
                      <div className={`w-2 h-2 rounded-full ${instance.shadowsocks_enable ? 'bg-green-500' : 'bg-muted-foreground/30'}`} />
                      <span className="font-semibold text-sm">Shadowsocks</span>
                      {instance.shadowsocks_enable ? <span className="text-xs text-green-600">已启用</span> : <span className="text-xs text-muted-foreground">未启用</span>}
                    </div>
                    {instance.shadowsocks_enable && (
                      <div className="grid grid-cols-2 gap-x-4 gap-y-1.5 text-sm ml-4">
                        <div className="text-muted-foreground">端口</div>
                        <div>{instance.shadowsocks_libev_port}</div>
                        <div className="text-muted-foreground">加密方法</div>
                        <div><code className="bg-muted px-1.5 py-0.5 rounded text-xs">{instance.shadowsocks_libev_method}</code></div>
                        <div className="text-muted-foreground">密码长度</div>
                        <div>{instance.shadowsocks_libev_password_length}</div>
                      </div>
                    )}
                  </div>

                  <div className="border-t pt-3">
                    <div className="flex items-center gap-2 mb-2">
                      <div className={`w-2 h-2 rounded-full ${instance.hysteria_enable ? 'bg-blue-500' : 'bg-muted-foreground/30'}`} />
                      <span className="font-semibold text-sm">Hysteria2</span>
                      {instance.hysteria_enable ? <span className="text-xs text-blue-600">已启用</span> : <span className="text-xs text-muted-foreground">未启用</span>}
                    </div>
                    {instance.hysteria_enable && (
                      <div className="grid grid-cols-2 gap-x-4 gap-y-1.5 text-sm ml-4">
                        <div className="text-muted-foreground">端口</div>
                        <div>{instance.hysteria_port || 8443}</div>
                        <div className="text-muted-foreground">密码长度</div>
                        <div>{instance.hysteria_password_length}</div>
                        <div className="text-muted-foreground">伪装 URL</div>
                        <div className="truncate" title={instance.hysteria_proxy_url}><code className="bg-muted px-1.5 py-0.5 rounded text-xs">{instance.hysteria_proxy_url}</code></div>
                      </div>
                    )}
                  </div>

                  <div className="border-t pt-3">
                    <div className="flex items-center gap-2 mb-2">
                      <div className={`w-2 h-2 rounded-full ${instance.xray_enable ? 'bg-purple-500' : 'bg-muted-foreground/30'}`} />
                      <span className="font-semibold text-sm">Xray</span>
                      {instance.xray_enable ? <span className="text-xs text-purple-600">已启用</span> : <span className="text-xs text-muted-foreground">未启用</span>}
                    </div>
                    {instance.xray_enable && (
                      <div className="grid grid-cols-2 gap-x-4 gap-y-1.5 text-sm ml-4">
                        <div className="text-muted-foreground">端口</div>
                        <div>{instance.xray_port}</div>
                        <div className="text-muted-foreground">伪装 URL</div>
                        <div className="truncate" title={instance.xray_proxy_url}><code className="bg-muted px-1.5 py-0.5 rounded text-xs">{instance.xray_proxy_url}</code></div>
                        <div className="text-muted-foreground">Private Key</div>
                        <div className="truncate font-mono text-xs" title={instance.xray_private_key}>{instance.xray_private_key || <span className="text-muted-foreground">—</span>}</div>
                        <div className="text-muted-foreground">Public Key</div>
                        <div className="truncate font-mono text-xs" title={instance.xray_public_key}>{instance.xray_public_key || <span className="text-muted-foreground">—</span>}</div>
                      </div>
                    )}
                  </div>

                  <div className="border-t pt-3">
                    <div className="flex items-center gap-2 mb-2">
                      <div className={`w-2 h-2 rounded-full ${instance.anytls_enable ? 'bg-amber-500' : 'bg-muted-foreground/30'}`} />
                      <span className="font-semibold text-sm">AnyTLS</span>
                      {instance.anytls_enable ? <span className="text-xs text-amber-600">已启用</span> : <span className="text-xs text-muted-foreground">未启用</span>}
                    </div>
                    {instance.anytls_enable && (
                      <div className="grid grid-cols-2 gap-x-4 gap-y-1.5 text-sm ml-4">
                        <div className="text-muted-foreground">端口</div>
                        <div>{instance.anytls_port || 8444}</div>
                        <div className="text-muted-foreground">密码长度</div>
                        <div>{instance.anytls_password_length}</div>
                        <div className="text-muted-foreground">伪装 URL</div>
                        <div className="truncate" title={instance.anytls_proxy_url}><code className="bg-muted px-1.5 py-0.5 rounded text-xs">{instance.anytls_proxy_url}</code></div>
                      </div>
                    )}
                  </div>

                  <div className="border-t pt-3">
                    <div className="flex items-center gap-2 mb-2">
                      <div className={`w-2 h-2 rounded-full ${instance.tuic_enable ? 'bg-emerald-500' : 'bg-muted-foreground/30'}`} />
                      <span className="font-semibold text-sm">TUIC v5</span>
                      {instance.tuic_enable ? <span className="text-xs text-emerald-600">已启用</span> : <span className="text-xs text-muted-foreground">未启用</span>}
                    </div>
                    {instance.tuic_enable && (
                      <div className="grid grid-cols-2 gap-x-4 gap-y-1.5 text-sm ml-4">
                        <div className="text-muted-foreground">端口</div>
                        <div>{instance.tuic_port || 8445}</div>
                        <div className="text-muted-foreground">密码长度</div>
                        <div>{instance.tuic_password_length}</div>
                        <div className="text-muted-foreground">伪装 URL</div>
                        <div className="truncate" title={instance.tuic_proxy_url}><code className="bg-muted px-1.5 py-0.5 rounded text-xs">{instance.tuic_proxy_url}</code></div>
                      </div>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}

        {hydrated && !loading && !needsAuth && !editMode && (data?.combined_instances || []).length === 0 && (
          <div className="flex flex-col items-center justify-center py-20 text-muted-foreground gap-2">
            <div className="text-4xl">🌐</div>
            <p className="text-sm">暂无实例，开启编辑后添加</p>
          </div>
        )}

        {/* 编辑模式 */}
        {!loading && !needsAuth && editMode && (
          <form onSubmit={handleSubmitInstanceConfig}>
            {formError && (
              <Alert variant="destructive" className="mb-4">
                <AlertDescription>{formError}</AlertDescription>
              </Alert>
            )}

            {instanceConfigs.map((instance, index) => (
              <Card className="mb-5 shadow-sm" key={index}>
                <CardHeader className="bg-muted/30 border-b">
                  <div className="flex items-center gap-3">
                    <span className="text-xs font-mono bg-primary/10 text-primary px-2 py-0.5 rounded-full">#{index + 1}</span>
                    <div className="flex-1 max-w-xs">
                      <Input
                        type="text"
                        placeholder="instance name"
                        value={instance.instance_name}
                        onChange={(e) => handleInstanceChange(index, 'instance_name', e.target.value)}
                        className="h-8 font-medium"
                      />
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      className="ml-auto text-muted-foreground hover:text-destructive"
                      onClick={() => handleRemoveInstanceConfig(index)}
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  {/* 基础配置 */}
                  <Card className="bg-muted/20">
                    <CardHeader className="border-b">
                      <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">基础配置</span>
                    </CardHeader>
                    <CardContent className="py-3">
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-3 items-end">
                        <div className="space-y-1">
                          <Label>region</Label>
                          <Select
                            value={instance.region}
                            onValueChange={(value) => handleInstanceChange(index, 'region', value)}
                          >
                            <SelectTrigger className="w-full">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {lightsail_regions.map(option => (
                                <SelectItem value={option.value} key={option.value}>{option.label}</SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="space-y-1">
                          <Label>availability_zone</Label>
                          <Select
                            key={`az-${index}-${instance.region}`}
                            value={instance.availability_zone}
                            onValueChange={(value) => handleInstanceChange(index, 'availability_zone', value)}
                          >
                            <SelectTrigger className="w-full">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {(lightsail_availability_zones[instance.region] || []).map(option => (
                                <SelectItem value={option.value} key={option.value}>{option.label}</SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="space-y-1">
                          <Label>create_static_ip</Label>
                          <div className="flex items-center h-9">
                            <Switch
                              checked={instance.create_static_ip}
                              onCheckedChange={(checked) => handleInstanceChange(index, 'create_static_ip', checked)}
                            />
                          </div>
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  {/* 协议配置 */}
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {/* Shadowsocks */}
                    <Card className={`flex flex-col transition-opacity ${!instance.shadowsocks_enable ? 'opacity-60' : ''}`}>
                      <CardHeader className="border-b bg-muted/20">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <div className={`w-1.5 h-1.5 rounded-full ${instance.shadowsocks_enable ? 'bg-green-500' : 'bg-muted-foreground'}`} />
                            <span className="font-semibold text-sm">Shadowsocks</span>
                          </div>
                          <Switch
                            checked={instance.shadowsocks_enable}
                            onCheckedChange={(checked) => handleInstanceChange(index, 'shadowsocks_enable', checked)}
                          />
                        </div>
                      </CardHeader>
                      <CardContent className="flex-1 space-y-3">
                        <div className="space-y-1">
                          <Label className="text-xs">shadowsocks_libev_method</Label>
                          <Select
                            value={instance.shadowsocks_libev_method}
                            onValueChange={(value) => handleInstanceChange(index, 'shadowsocks_libev_method', value)}
                            disabled={!instance.shadowsocks_enable}
                          >
                            <SelectTrigger className="w-full">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {shadowsocks_libev_method_options.map(option => (
                                <SelectItem value={option.value} key={option.value}>{option.label}</SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">shadowsocks_libev_port</Label>
                          <Input
                            type="number"
                            value={instance.shadowsocks_libev_port}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'shadowsocks_libev_port', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.shadowsocks_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">shadowsocks_libev_password_length</Label>
                          <Input
                            type="number"
                            value={instance.shadowsocks_libev_password_length}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'shadowsocks_libev_password_length', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.shadowsocks_enable}
                          />
                        </div>
                      </CardContent>
                    </Card>

                    {/* Hysteria */}
                    <Card className={`flex flex-col transition-opacity ${!instance.hysteria_enable ? 'opacity-60' : ''}`}>
                      <CardHeader className="border-b bg-muted/20">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <div className={`w-1.5 h-1.5 rounded-full ${instance.hysteria_enable ? 'bg-blue-500' : 'bg-muted-foreground'}`} />
                            <span className="font-semibold text-sm">Hysteria</span>
                          </div>
                          <Switch
                            checked={instance.hysteria_enable}
                            onCheckedChange={(checked) => handleInstanceChange(index, 'hysteria_enable', checked)}
                          />
                        </div>
                      </CardHeader>
                      <CardContent className="flex-1 space-y-3">
                        <div className="space-y-1">
                          <Label className="text-xs">hysteria_port</Label>
                          <Input
                            type="number"
                            value={instance.hysteria_port ?? 8443}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'hysteria_port', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.hysteria_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">hysteria_password_length</Label>
                          <Input
                            type="number"
                            value={instance.hysteria_password_length}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'hysteria_password_length', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.hysteria_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">hysteria_proxy_url</Label>
                          <Input
                            type="text"
                            value={instance.hysteria_proxy_url}
                            onChange={(e) => handleInstanceChange(index, 'hysteria_proxy_url', e.target.value)}
                            disabled={!instance.hysteria_enable}
                          />
                        </div>
                      </CardContent>
                    </Card>

                    {/* Xray */}
                    <Card className={`flex flex-col transition-opacity ${!instance.xray_enable ? 'opacity-60' : ''}`}>
                      <CardHeader className="border-b bg-muted/20">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <div className={`w-1.5 h-1.5 rounded-full ${instance.xray_enable ? 'bg-purple-500' : 'bg-muted-foreground'}`} />
                            <span className="font-semibold text-sm">Xray</span>
                          </div>
                          <Switch
                            checked={instance.xray_enable}
                            onCheckedChange={(checked) => handleInstanceChange(index, 'xray_enable', checked)}
                          />
                        </div>
                      </CardHeader>
                      <CardContent className="flex-1 space-y-3">
                        <div className="space-y-1">
                          <Label className="text-xs">xray_port</Label>
                          <Input
                            type="number"
                            value={instance.xray_port}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'xray_port', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.xray_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">xray_proxy_url</Label>
                          <Input
                            type="text"
                            value={instance.xray_proxy_url}
                            onChange={(e) => handleInstanceChange(index, 'xray_proxy_url', e.target.value)}
                            disabled={!instance.xray_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">xray_private_key</Label>
                          <Input
                            type="text"
                            value={instance.xray_private_key}
                            onChange={(e) => handleInstanceChange(index, 'xray_private_key', e.target.value)}
                            disabled={!instance.xray_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">xray_public_key</Label>
                          <Input
                            type="text"
                            value={instance.xray_public_key}
                            onChange={(e) => handleInstanceChange(index, 'xray_public_key', e.target.value)}
                            disabled={!instance.xray_enable}
                          />
                        </div>
                      </CardContent>
                    </Card>

                    {/* AnyTLS */}
                    <Card className={`flex flex-col transition-opacity ${!instance.anytls_enable ? 'opacity-60' : ''}`}>
                      <CardHeader className="border-b bg-muted/20">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <div className={`w-1.5 h-1.5 rounded-full ${instance.anytls_enable ? 'bg-amber-500' : 'bg-muted-foreground'}`} />
                            <span className="font-semibold text-sm">AnyTLS</span>
                          </div>
                          <Switch
                            checked={instance.anytls_enable}
                            onCheckedChange={(checked) => handleInstanceChange(index, 'anytls_enable', checked)}
                          />
                        </div>
                      </CardHeader>
                      <CardContent className="flex-1 space-y-3">
                        <div className="space-y-1">
                          <Label className="text-xs">anytls_port</Label>
                          <Input
                            type="number"
                            value={instance.anytls_port ?? 8444}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'anytls_port', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.anytls_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">anytls_password_length</Label>
                          <Input
                            type="number"
                            value={instance.anytls_password_length}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'anytls_password_length', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.anytls_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">anytls_proxy_url</Label>
                          <Input
                            type="text"
                            value={instance.anytls_proxy_url}
                            onChange={(e) => handleInstanceChange(index, 'anytls_proxy_url', e.target.value)}
                            disabled={!instance.anytls_enable}
                          />
                        </div>
                      </CardContent>
                    </Card>

                    {/* TUIC v5 */}
                    <Card className={`flex flex-col transition-opacity ${!instance.tuic_enable ? 'opacity-60' : ''}`}>
                      <CardHeader className="border-b bg-muted/20">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <div className={`w-1.5 h-1.5 rounded-full ${instance.tuic_enable ? 'bg-emerald-500' : 'bg-muted-foreground'}`} />
                            <span className="font-semibold text-sm">TUIC v5</span>
                          </div>
                          <Switch
                            checked={instance.tuic_enable}
                            onCheckedChange={(checked) => handleInstanceChange(index, 'tuic_enable', checked)}
                          />
                        </div>
                      </CardHeader>
                      <CardContent className="flex-1 space-y-3">
                        <div className="space-y-1">
                          <Label className="text-xs">tuic_port</Label>
                          <Input
                            type="number"
                            value={instance.tuic_port ?? 8445}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'tuic_port', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.tuic_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">tuic_password_length</Label>
                          <Input
                            type="number"
                            value={instance.tuic_password_length}
                            onChange={(e) => {
                              const raw = e.target.value
                              handleInstanceChange(index, 'tuic_password_length', raw === '' ? '' : parseInt(raw) || 0)
                            }}
                            disabled={!instance.tuic_enable}
                          />
                        </div>
                        <div className="space-y-1">
                          <Label className="text-xs">tuic_proxy_url</Label>
                          <Input
                            type="text"
                            value={instance.tuic_proxy_url}
                            onChange={(e) => handleInstanceChange(index, 'tuic_proxy_url', e.target.value)}
                            disabled={!instance.tuic_enable}
                          />
                        </div>
                      </CardContent>
                    </Card>
                  </div>
                </CardContent>
              </Card>
            ))}

            <div className="border rounded-xl p-4 bg-background flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
              <Input
                type="password"
                placeholder="Auth Token"
                value={authToken}
                onChange={(e) => setAuthToken(e.target.value)}
                className="flex-1"
              />
              <div className="flex gap-2">
                <Button type="button" variant="outline" onClick={handleAddInstanceConfig} className="flex-1 sm:flex-none">
                  + 增加实例
                </Button>
                <Button type="submit" disabled={loading} className="flex-1 sm:flex-none">
                  {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  提交配置
                </Button>
              </div>
            </div>
          </form>
        )}
      </main>
    </div>
  )
}

