export default async function handler(req, res) {
  console.log('>>>>>>>>>> API HIT! Method:', req.method);

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    let queryData = req.body?.data;
    if (!queryData && typeof req.body === 'string') {
      const params = new URLSearchParams(req.body);
      queryData = params.get('data');
    }

    console.log('Query Data present:', !!queryData);

    const response = await fetch('https://lz4.overpass-api.de/api/interpreter', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'BkkTransitPlanner/1.0',
      },
      body: `data=${encodeURIComponent(queryData || '')}`,
    });

    const data = await response.text();
    console.log('Overpass Response Status:', response.status);

    res.setHeader('Content-Type', response.headers.get('content-type') || 'application/json');
    res.status(response.status).send(data);
  } catch (e) {
    console.error('PROXY ERROR:', e.message);
    res.status(500).json({ error: e.message });
  }
}
