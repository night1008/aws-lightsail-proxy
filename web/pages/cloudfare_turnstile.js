import Head from 'next/head'

export default function CloudfareTurnstile() {
  return (
    <div className="container">
      <Head>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
      </Head>

      <form action="/login" method="POST">
        <input type="text" placeholder="username" />
        <input type="password" placeholder="password" />
        <div className="cf-turnstile" data-sitekey="0x4AAAAAAALovSRVqJoLSnud"></div>
        <button type="submit" value="Submit">Log in</button>
      </form>
    </div>
  )
}