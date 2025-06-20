import fetch from 'node-fetch'

const getToken = async () => {
  const baseUrl = 'http://localhost:3000/api' // your Payload dev URL
  const email = 'admin@example.com' // your admin user email
  const password = 'adminpassword' // your admin user password

  const res = await fetch(`${baseUrl}/users/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ email, password }),
  })

  if (!res.ok) {
    const error = await res.text()
    console.error('❌ Failed to login:', error)
    process.exit(1)
  }

  const json = await res.json()
  const token = json.token

  console.log('✅ Token:', token)
  return token
}

getToken()
