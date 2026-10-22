#!/usr/bin/env python3
"""Exercise the actual offline joiner UI using the shared Chromium browser.
Run after splitting the signed release. No APK bytes are sent over the network.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess


def browser(*args):
    result = subprocess.run(['coderabbit-agent-browser', *args], text=True, capture_output=True, check=True,
        env={**os.environ, 'AGENT_BROWSER_DEFAULT_TIMEOUT': '180000'})
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--download', type=Path, required=True)
    args = parser.parse_args()
    manifest = args.manifest.resolve()
    data = json.loads(manifest.read_text())
    parts = [str(manifest.parent / p['name']) for p in data['parts']]
    browser('open', Path('apk-joiner.html').resolve().as_uri())
    # Actual File objects from disk, reverse order with manifest between parts.
    selected = list(reversed(parts))
    selected.insert(1, str(manifest))
    browser('upload', '#files', *selected)
    browser('eval', 'globalThis.originalFiles = [...document.querySelector("#files").files]; true')
    browser('click', '#join')
    print(browser('eval', '''(async()=>{
      const deadline=Date.now()+120000;
      while(document.querySelector('#join').disabled) {
        if(Date.now()>deadline)throw Error('Join timed out');
        await new Promise(r=>setTimeout(r,100));
      }
      if(document.querySelector('#download').hidden)throw Error(document.querySelector('#status').textContent);
      return {case:'signed APK in random order',status:'PASS',filename:document.querySelector('#download').download};
    })()'''))
    browser('download', '#download', str(args.download.resolve()))
    # Drive change/Join handlers for failure cases, including a duplicate File.
    print(browser('eval', '''(async()=>{
      const all=globalThis.originalFiles, mf=all.find(f=>f.name.endsWith('.manifest.json'));
      const parts=all.filter(f=>f!==mf), first=parts[0];
      const flipped=new Uint8Array(await first.arrayBuffer());flipped[0]^=1;
      const wrongHash=JSON.parse(await mf.text());wrongHash.sha256='0'.repeat(64);
      const cases=[
        ['missing part',[mf,...parts.slice(1)],'Missing part: '+first.name],
        ['wrong size',[mf,new File([await first.slice(1).arrayBuffer()],first.name),...parts.slice(1)],'Wrong size: '+first.name],
        ['flipped byte',[mf,new File([flipped],first.name),...parts.slice(1)],'SHA-256 mismatch: '+first.name],
        ['duplicate part',[...all,first],'Duplicate part: '+first.name],
        ['no manifest',parts,'No manifest selected'],
        ['wrong total hash',[new File([JSON.stringify(wrongHash)],mf.name),...parts],'Whole APK SHA-256 mismatch']
      ];const results=[];
      for(const [name,files,expected] of cases){
        const transfer=new DataTransfer();files.forEach(f=>transfer.items.add(f));
        const input=document.querySelector('#files');input.files=transfer.files;input.dispatchEvent(new Event('change'));
        document.querySelector('#join').click();
        const deadline=Date.now()+120000;
        while(document.querySelector('#join').disabled){if(Date.now()>deadline)throw Error(name+': timeout');await new Promise(r=>setTimeout(r,50));}
        const status=document.querySelector('#status').textContent;
        if(!status.includes(expected)||!document.querySelector('#download').hidden)throw Error(name+': '+status);
        results.push({case:name,status:'PASS',message:status});
      }
      // Exercise pure JS on the actual signed parts too, as on local browsers
      // where WebCrypto is unavailable. Total is always incremental SHA256.
      const fallback=await ApkJoiner.joinParts(all,()=>{},null);
      results.push({case:'signed APK pure-JS fallback',status:'PASS',sha256:fallback.sha256});
      return results;
    })()'''))
    print(browser('eval', "(async()=>{\nconst all=globalThis.originalFiles, mf=all.find(f=>f.name.endsWith('.manifest.json'));\nconst m=JSON.parse(await mf.text()), transfer=new DataTransfer();transfer.items.add(mf);\nfor(const p of [...m.parts].sort((a,b)=>a.index-b.index))transfer.items.add(all.find(f=>f.name===p.name));\nconst input=document.querySelector('#files');input.files=transfer.files;input.dispatchEvent(new Event('change'));\ndocument.querySelector('#join').click();const deadline=Date.now()+120000;\nwhile(document.querySelector('#join').disabled){if(Date.now()>deadline)throw Error('Ordered happy path timeout');await new Promise(r=>setTimeout(r,50));}\nif(document.querySelector('#download').hidden)throw Error(document.querySelector('#status').textContent);\nreturn {case:'ordered happy path',status:'PASS',filename:document.querySelector('#download').download,resourceRequests:performance.getEntriesByType('resource').length};\n})()"))
    print('PASS: browser download link worked under exact CSP on file://. Verify downloaded APK separately.')


if __name__ == '__main__':
    main()
