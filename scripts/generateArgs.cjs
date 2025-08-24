const fs = require('fs');

const [, , filePath] = process.argv;

// Load your deployment JSON
const raw = fs.readFileSync(filePath, 'utf8');

const data = raw
    .split('\n')
    .filter(line => line.trim()) // remove empty lines
    .map(line => JSON.parse(line))
    .filter(obj => !!obj?.['constructorArgs'])[0];

// Extract constructorArgs and normalize bigint objects
const args = data.constructorArgs.map(arg => {
    if (typeof arg === 'object' && arg._kind === 'bigint') {
        return arg.value; // Use the stringified bigint
    }
    return arg;
});


// // Write to args.js
const output = `const constructorArgs = ${JSON.stringify(args, null, 2)};\n export default constructorArgs;`;


const newFilePath = filePath.split('/').slice(0, -1).join('/') + '/constructor-args.ts';

fs.writeFileSync(newFilePath, output);

console.log('✅ Constructor args written to', newFilePath);