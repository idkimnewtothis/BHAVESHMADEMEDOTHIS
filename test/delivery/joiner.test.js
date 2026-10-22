const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const {createHash, webcrypto} = require('node:crypto');
const html = fs.readFileSync('apk-joiner.html', 'utf8');
vm.runInThisContext(html.match(/<script>([\s\S]*)<\/script>/)[1]);
const {Sha256, joinParts} = globalThis.ApkJoiner;
const sha = b => createHash('sha256').update(b).digest('hex');
const file = (name, bytes) => new File([bytes], name);
const bytes = Buffer.from(Array.from({length:10003}, (_,i)=>i%251));
const chunks = [bytes.subarray(0,4000),bytes.subarray(4000,8000),bytes.subarray(8000)];
const m = {app:'Test',version:'1',file:'test.apk',size:bytes.length,sha256:sha(bytes),part_size:4000,
 parts:chunks.map((b,i)=>({index:i+1,name:`test.part-${i+1}.bin`,size:b.length,sha256:sha(b)}))};
const mf = value => file('test.manifest.json',JSON.stringify(value));
const parts = chunks.map((b,i)=>file(m.parts[i].name,b));
(async()=>{
 let count=0;
 for(const input of [Buffer.alloc(0),Buffer.from('abc'),Buffer.alloc(1000000,97),bytes]) {
  const hash=new Sha256();for(let i=0;i<input.length;i+=31)hash.update(input.subarray(i,i+31));assert.equal(hash.hex(),sha(input));count++;
 }
 for(const subtle of [webcrypto.subtle,null,{digest:async()=>{throw Error('local file crypto blocked');}}]) {
  const result=await joinParts([mf(m),...parts],()=>{},subtle);assert.equal(sha(Buffer.from(await result.blob.arrayBuffer())),sha(bytes));count++;
 }
 const joined=await joinParts([parts[2],mf(m),parts[0],parts[1]]);assert.equal(sha(Buffer.from(await joined.blob.arrayBuffer())),sha(bytes));count++;
 await assert.rejects(joinParts([mf(m),...parts.slice(1)]),/Missing part: test.part-1.bin/);count++;
 await assert.rejects(joinParts([mf(m),file(parts[0].name,chunks[0].subarray(1)),...parts.slice(1)]),/Wrong size: test.part-1.bin/);count++;
 const flipped=Buffer.from(chunks[0]);flipped[3]^=1;
 await assert.rejects(joinParts([mf(m),file(parts[0].name,flipped),...parts.slice(1)]),/SHA-256 mismatch: test.part-1.bin/);count++;
 await assert.rejects(joinParts([mf(m),...parts,parts[0]]),/Duplicate part: test.part-1.bin/);count++;
 await assert.rejects(joinParts(parts),/No manifest selected/);count++;
 await assert.rejects(joinParts([mf({...m,sha256:'0'.repeat(64)}),...parts]),/Whole APK SHA-256 mismatch/);count++;
 await assert.rejects(joinParts([mf(m),...parts,file('extra.bin','x')]),/Extra part: extra.bin/);count++;
 console.log(`PASS: ${count} joiner algorithm and failure-case checks. Synthetic fixture; signed APK and browser UI checks are separate.`);
})().catch(e=>{console.error(e);process.exitCode=1;});
