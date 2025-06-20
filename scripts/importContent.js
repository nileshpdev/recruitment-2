import fs from 'fs'
import path from 'path'

const fetch = global.fetch
const email = 'nile2h+admin@gmail.com'
const password = 'Password1'
const baseUrl = 'http://localhost:3001/api' // TEST environment

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

async function importCollections(token) {
  const collections = ['pages'] // Replace with your collections
  const importDir = path.resolve('./scripts/exported')

  for (const collection of collections) {
    const filePath = path.join(importDir, `${collection}.json`)
    if (!fs.existsSync(filePath)) {
      console.warn(`⚠️  No file found for ${collection}, skipping.`)
      continue
    }

    const docs = JSON.parse(fs.readFileSync(filePath, 'utf-8'))

    console.log(`⏳ Importing ${collection} (${docs.length} items)...`)

    for (const doc of docs) {
      try {
        const res = await fetch(`${baseUrl}/${collection}`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify(doc),
        })

        if (!res.ok) {
          const error = await res.text()
          console.error(`❌ Failed to import to ${collection}:`, error)
        }
      } catch (err) {
        console.error(`❌ Error importing to ${collection}:`, err.message)
      }
    }

    console.log(`✅ Imported ${collection}`)
  }
}

getToken()
  .then((token) => importCollections(token))
  .catch((err) => console.error('❌ Failed to import:', err.message))
