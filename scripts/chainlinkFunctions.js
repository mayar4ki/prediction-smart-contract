

const question = args[0];
const date = args[1];

const payload = `
question: "${prompt}"  
Prediction Date: "${date}"
`;

const apiResponse = await Functions.makeHttpRequest({
  url: "https://api.openai.com/v1/responses",
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${secrets.openaiKey}`
  },
  method: "POST",
  data: {
    "prompt": {
      "id": "pmpt_689e252d9ba081948c781705febb11a205cedd72e412f82a",
      "version": "4"
    }
  },
  timeout: 9000
});


if (apiResponse.error || apiResponse?.data?.status !== 'completed') {
  return Functions.encodeString("ERR:api")
}


try {
  const output = apiResponse?.data?.output?.filter(e => e.role === "assistant");
  const tmp = JSON.parse(output?.[0]?.content?.[0]?.text ?? '{ "answer":"yes" }');
  return Functions.encodeString(tmp.answer ?? "ERR:prop-404");
}
catch {
  return Functions.encodeString(tmp.answer ?? "ERR:parse");
}