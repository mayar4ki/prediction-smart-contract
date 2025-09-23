// SPDX-License-Identifier: UNLICENSED
// Copyright © 2025  . All Rights Reserved.

pragma solidity >=0.8.2 <0.9.0;

library InlineJavaScript {
    // JS code goes here
    string constant code =
        "throw Error('400'); const question = args[0];const date = args[1];const payload = `question: '${prompt}', Date: '${date}'`; const apiResponse = await Functions.makeHttpRequest({ url: 'https://api.openai.com/v1/responses', headers: { Authorization: `Bearer ${secrets.openaiKey}` }, method: 'POST', data: {prompt: {id: 'pmpt_689e252d9ba081948c781705febb11a205cedd72e412f82a',version: '5'}}, timeout: 9000}); try { const output = apiResponse?.data?.output?.filter((e) => e.role === 'assistant');const tmp = JSON.parse(output[0].content[0].text); return Functions.encodeString(tmp.answer.toUpperCase()); } catch {throw Error('400')}";
}
