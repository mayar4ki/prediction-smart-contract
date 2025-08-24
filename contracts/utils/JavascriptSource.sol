// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

abstract contract JavascriptSource {
    // JS code goes here
    string constant javascriptSourceCode =
  "const question = args[0]"
  "const date = args[1]"
  ""
  "const payload = `"
  "question: '${prompt}'  "
  "Prediction Date: '${date}'"
  "`"
  "const apiResponse = await Functions.makeHttpRequest({"
  "    url: 'https://api.openai.com/v1/responses',"
  "    headers: {"
  "        'Content-Type': 'application/json',"
  "        Authorization: `Bearer ${secrets.openaiKey}`,"
  "    },"
  "    method: 'POST',"
  "    data: {"
  "        prompt: {"
  "            id: 'pmpt_689e252d9ba081948c781705febb11a205cedd72e412f82a',"
  "            version: '5',"
  "        },"
  "    },"
  "    timeout: 9000,"
  "})"
  ""
  "if (apiResponse.error || apiResponse?.data?.status !== 'completed') {"
  "    return Functions.encodeString(apiResponse?.status ?? '500')"
  "}"
  ""
  "try {"
  "    const output = apiResponse?.data?.output?.filter("
  "        (e) => e.role === 'assistant'"
  "    )"
  "    const tmp = JSON.parse(output[0].content[0].text)"
  "    if (tmp?.answer) {"
  "        return Functions.encodeString(tmp.answer.toUpperCase())"
  "    }"
  "    throw Error('400')"
  "} catch {"
  "    throw Error('400')"
  "}";
}
