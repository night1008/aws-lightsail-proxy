// 本地开发 mock API 路由
// 线上通过 next.config.js rewrites 仅在 development 时生效
import { mockSubmit } from '@/lib/mocks/api'

export default function handler(req, res) {
  return mockSubmit(req, res)
}
