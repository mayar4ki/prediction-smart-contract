

const prompt = args[0];

const apiResponse = await Functions.makeHttpRequest({
    url: "https://api.openai.com/v1/responses",
    headers: { 
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${secrets.openaiKey}`
         },
    method:"POST",
    data:{
        "model": "gpt-4.1",
  "input": [
    { role: "user", content:prompt }
  ],
    "text": {
      "format": {
        "type": "json_schema",
        "name": "question_answer",
        "schema": {
          "type": "object",
          "properties": {
            "answer": { "type": "string","enum": ["yes", "no", "unknown"] }
          },
          "required": ["answer"],
          "additionalProperties": false
        },
        "strict": true
      }
    },
  "reasoning": {},
  "tools": [{"type": "web_search_preview","search_context_size": "medium" }],
  "temperature": 1,
  "max_output_tokens": 1000,
  "top_p": 1,
  "store": false
    }
});


if (apiResponse.error || apiResponse?.data?.status !== 'completed') {
    console.log(apiResponse)
    return Functions.encodeString("ERROR")
}


console.log(apiResponse.data.output[0].content)

// Return Character Name
return Functions.encodeString("data")
