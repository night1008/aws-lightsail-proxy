/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // 本地开发时将 /api/input、/api/submit 代理到 mock 路由
  // 线上 Vercel 部署时 rewrites 不生效，由 api/*.go Go functions 处理
  async rewrites() {
    if (process.env.NODE_ENV === 'development') {
      return [
        { source: '/api/input', destination: '/api/dev-input' },
        { source: '/api/submit', destination: '/api/dev-submit' },
      ]
    }
    return []
  },
}

module.exports = nextConfig
