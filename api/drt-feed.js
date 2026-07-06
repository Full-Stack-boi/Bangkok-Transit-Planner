export default async function handler(req, res) {
  console.log('>>>>>>>>>> API HIT! Method:', req.method);

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    const response = await fetch('https://www.drt.go.th/feed', {
      method: 'GET',
      headers: {
        'User-Agent': 'BkkTransitPlanner/1.0',
      },
    });

    const data = await response.text();
    console.log('DRT Feed Response Status:', response.status);

    res.setHeader('Content-Type', response.headers.get('content-type') || 'application/xml');
    res.status(response.status).send(data);
  } catch (e) {
    console.error('PROXY ERROR:', e.message);
    res.status(500).json({ error: e.message });
  }
}
