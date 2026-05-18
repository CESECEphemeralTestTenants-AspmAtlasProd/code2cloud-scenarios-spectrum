const express = require('express');
const Ajv = require('ajv');
const lodash = require('lodash');

const app = express();
const ajv = new Ajv();
const port = process.env.PORT || 3001;

app.use(express.json());

app.get('/health', (_request, response) => {
  response.json({ status: 'ok', scenario: 'vulnerable-api' });
});

app.post('/merge', (request, response) => {
  const schema = { type: 'object' };
  const valid = ajv.validate(schema, request.body);
  const merged = lodash.merge({}, request.body);
  response.json({ valid, merged, errors: ajv.errors || [] });
});

app.listen(port, () => {
  console.log(`vulnerable-api listening on ${port}`);
});