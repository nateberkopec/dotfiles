import fs from 'node:fs/promises'

const purlRegex = /^pkg:npm\/((?:@[^/]+\/)?(?:[^@]+))@(.+)$/
const userAgent = 'dotfiles-aube-socket-security-scanner'

async function socketApiKey() {
  const envToken = process.env.SOCKET_API_KEY || process.env.SOCKET_SECURITY_API_TOKEN
  if (envToken) return envToken

  const settingsPath = socketSettingsPath()
  if (!settingsPath) return null

  try {
    const rawContent = await fs.readFile(settingsPath, 'utf8')
    return JSON.parse(Buffer.from(rawContent, 'base64').toString().trim()).apiToken || null
  } catch {
    return null
  }
}

function socketSettingsPath() {
  if (process.platform === 'win32') {
    return process.env.LOCALAPPDATA ? `${process.env.LOCALAPPDATA}\\socket\\settings` : null
  }

  if (process.env.XDG_DATA_HOME) return `${process.env.XDG_DATA_HOME}/socket/settings`

  const home = process.env.HOME
  if (!home) return null

  if (process.platform === 'darwin') return `${home}/Library/Application Support/socket/settings`

  return `${home}/.local/share/socket/settings`
}

async function fetchUnauthenticated(purls) {
  const urls = purls.map(purl => `https://firewall-api.socket.dev/purl/${encodeURIComponent(purl)}`)
  const responses = await Promise.all(urls.map(url => fetch(url, { headers: { 'User-Agent': userAgent } })))

  return parseResponses(responses)
}

async function fetchAuthenticated(purls, apiKey) {
  const response = await fetch('https://api.socket.dev/v0/purl?actions=error,warn', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'User-Agent': userAgent,
    },
    body: JSON.stringify({ components: purls.map(purl => ({ purl })) }),
  })

  return parseResponses([response])
}

async function parseResponses(responses) {
  const artifacts = []

  for (const response of responses) {
    if (!response.ok) throw new Error(`Socket Security Scanner: received ${response.status} from server`)

    const text = await response.text()
    artifacts.push(...text.split('\n').filter(Boolean).map(line => JSON.parse(line)))
  }

  return artifacts
}

function purlFor(pkg) {
  return `pkg:npm/${pkg.name}@${pkg.version}`
}

function advisoryFor(artifact, alert) {
  const match = artifact.inputPurl.match(purlRegex)
  if (!match) return null

  const name = match[1]
  const version = match[2]
  const description = ['']

  if (alert.type === 'didYouMean') {
    description.push(`This package could be a typo-squatting attempt of another package (${alert.props.alternatePackage}).`)
  }

  if (alert.props.description) description.push(alert.props.description)
  if (alert.props.note) description.push(alert.props.note)
  if (alert.fix?.description) description.push(`Fix: ${alert.fix.description}`)

  return {
    level: alert.action === 'error' ? 'fatal' : 'warn',
    package: artifact.inputPurl,
    url: `https://socket.dev/npm/package/${name}/overview/${version}`,
    description: `${description.join('\n\n')}\n`,
  }
}

export const scanner = {
  version: '1',
  async scan({ packages }) {
    const apiKey = await socketApiKey()
    const advisories = []
    const purls = packages.map(purlFor)

    for (let i = 0; i < purls.length; i += 50) {
      const batch = purls.slice(i, i + 50)
      const artifacts = apiKey ? await fetchAuthenticated(batch, apiKey) : await fetchUnauthenticated(batch)

      for (const artifact of artifacts) {
        for (const alert of artifact.alerts || []) {
          const advisory = advisoryFor(artifact, alert)
          if (advisory) advisories.push(advisory)
        }
      }
    }

    return advisories
  },
}
