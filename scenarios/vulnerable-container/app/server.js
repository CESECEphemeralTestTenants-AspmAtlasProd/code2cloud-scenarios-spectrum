const express = require('express');
const Ajv = require('ajv');

const app = express();
const ajv = new Ajv();
const port = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (_request, response) => {
  response.json({ status: 'ok', scenario: 'vulnerable-container' });
});

app.post('/validate', (request, response) => {
  const schema = {
    type: 'object',
    properties: {
      name: { type: 'string' }
    }
  };
  const valid = ajv.validate(schema, request.body);
  response.json({ valid, errors: ajv.errors || [] });
});

app.listen(port, () => {
  console.log(`vulnerable-container listening on ${port}`);
});