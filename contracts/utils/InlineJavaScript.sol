// SPDX-License-Identifier: UNLICENSED
// Copyright © 2025  . All Rights Reserved.

pragma solidity >=0.8.2 <0.9.0;

library InlineJavaScript {
    // JS code goes here
    string constant code =
        "const apiResponse = await Functions.makeHttpRequest({url: 'https://api.openai.com/v1/responses', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${secrets.openaiKey}` },method: 'POST', data: { prompt: { id: 'pmpt_689e252d9ba081948c781705febb11a205cedd72e412f82a', version:'5' },input: [ { role: 'user', content: `question: '${args[0]}', Date: '${args[1]}'` }] }, timeout: 9000 }); if (apiResponse.error) { throw Error(apiResponse.status);}try { const output = apiResponse?.data?.output?.filter((e) => e.role === 'assistant'); return Functions.encodeString(JSON.parse(output[0].content[0].text).answer.toUpperCase()) } catch { throw Error('parse') }";
}
