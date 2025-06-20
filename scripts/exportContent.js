import fs from 'fs'
import path from 'path'

const fetch = global.fetch
const email = 'nile2h+admin@gmail.com'
const password = 'Password1'
const baseUrl = 'http://localhost:3000/api' // DEV environment

async function getToken() {
  const res = await fetch(`${baseUrl}/users/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  })

  if (!res.ok) {
    const error = await res.text()
    throw new Error(`Login failed: ${error}`)
  }

  const json = await res.json()
  return json.token
}

async function exportCollections(token) {
  const collections = ['pages'] // Replace with your actual collections
  const exportDir = path.resolve('./scripts/exported')

  if (!fs.existsSync(exportDir)) {
    fs.mkdirSync(exportDir, { recursive: true })
  }

  for (const collection of collections) {
    try {
      const res = await fetch(`${baseUrl}/${collection}?limit=1000`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      })

      if (!res.ok) {
        const error = await res.text()
        console.error(`❌ Failed to fetch ${collection}:`, error)
        continue
      }

      const json = await res.json()
      fs.writeFileSync(
        path.join(exportDir, `${collection}.json`),
        JSON.stringify(json.docs, null, 2),
      )

      console.log(`✅ Exported ${collection} (${json.docs.length} items)`)
    } catch (err) {
      console.error(`❌ Error exporting ${collection}:`, err.message)
    }
  }
}

getToken()
  .then((token) => exportCollections(token))
  .catch((err) => console.error('❌ Failed to export:', err.message))
