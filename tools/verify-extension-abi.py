#!/usr/bin/env python3
"""Check DEX member references against the actual release host's API.

Reads method/field definitions (not just symbol tables), follows superclass and
interface inheritance, and checks override descriptors for host API method names.
No APK code is executed. Reflection and dynamically generated calls need device
verification. The host API is implemented against extensions-lib v17, with
legacy 14/16 entry points. Exit 1 means the extension must not be trusted to run.
"""
import argparse
import json
from pathlib import Path
import struct
import sys
import zipfile

API = ('Leu/kanade/tachiyomi/source/', 'Leu/kanade/tachiyomi/animesource/', 'Leu/kanade/tachiyomi/network/',
       'Leu/kanade/tachiyomi/util/', 'Leu/kanade/tachiyomi/AppInfo;', 'Ltachiyomi/')

class Dex:
    def __init__(self, data):
        self.data = data
        if data[:4] != b'dex\n':
            raise ValueError('Not a standard DEX file')
        def table(offset):
            return struct.unpack_from('<II', data, offset)
        n, off = table(56)
        self.strings = []
        for i in range(n):
            ptr = self.u32(off + 4*i)
            _, ptr = self.uleb(ptr)
            self.strings.append(data[ptr:data.index(b'\0',ptr)].decode('utf-8',errors='replace'))
        n, off = table(64)
        self.types = [self.strings[self.u32(off+4*i)] for i in range(n)]
        n, off = table(72)
        protos = []
        for i in range(n):
            _, ret, params = struct.unpack_from('<III', data, off+12*i)
            args = self.type_list(params)
            protos.append('(' + ''.join(args) + ')' + self.types[ret])
        n, off = table(80)
        self.fields = []
        for i in range(n):
            cls, typ, name = struct.unpack_from('<HHI', data, off+8*i)
            self.fields.append((self.types[cls], self.strings[name], self.types[typ]))
        n, off = table(88)
        self.methods = []
        for i in range(n):
            cls, proto, name = struct.unpack_from('<HHI', data, off+8*i)
            self.methods.append((self.types[cls], self.strings[name], protos[proto]))
        self.parents = {}; self.defined_methods=set(); self.defined_fields=set(); self.virtual_methods=set()
        n, off = table(96)
        for i in range(n):
            cls, _, parent, interfaces, _, _, classdata, _ = struct.unpack_from('<8I', data, off+32*i)
            name = self.types[cls]
            self.parents[name] = ([] if parent == 0xffffffff else [self.types[parent]]) + self.type_list(interfaces)
            if not classdata:
                continue
            pos=classdata; counts=[]
            for _ in range(4):
                count,pos=self.uleb(pos);counts.append(count)
            for group, count in enumerate(counts):
                index=0
                for _ in range(count):
                    diff,pos=self.uleb(pos);index+=diff
                    _,pos=self.uleb(pos)
                    if group < 2:
                        self.defined_fields.add(self.fields[index])
                    else:
                        _,pos=self.uleb(pos)
                        self.defined_methods.add(self.methods[index])
                        if group == 3: self.virtual_methods.add(self.methods[index])
    def u32(self, pos):
        return struct.unpack_from('<I',self.data,pos)[0]
    def uleb(self,pos):
        result=0
        for shift in range(0,35,7):
            b=self.data[pos];pos+=1;result|=(b&127)<<shift
            if b<128:return result,pos
        raise ValueError('Invalid DEX ULEB128')
    def type_list(self,pos):
        if not pos:return []
        return [self.types[struct.unpack_from('<H', self.data, pos+4+2*i)[0]] for i in range(self.u32(pos))]

def load(apk):
    with zipfile.ZipFile(apk) as z:
        return [Dex(z.read(n)) for n in z.namelist() if n.startswith('classes') and n.endswith('.dex')]

def verify(host, extension):
    methods=set();fields=set();parents={}
    for dex in host+extension:
        methods.update(dex.defined_methods);fields.update(dex.defined_fields);parents.update(dex.parents)
    def resolve(symbol, definitions, visited=None):
        if symbol in definitions:return True
        owner,name,desc=symbol
        visited=set() if visited is None else visited
        if owner in visited or name=='<init>':return False
        visited.add(owner)
        return any(resolve((p,name,desc),definitions,visited) for p in parents.get(owner,[]))
    method_index={}
    for dex in host:
        for method in getattr(dex, "virtual_methods", dex.defined_methods):
            method_index.setdefault(method[:2], []).append(method)
    failures=set();checked=0
    for dex in extension:
        for refs,defs,kind in [(dex.methods,methods,'method'),(dex.fields,fields,'field')]:
            for symbol in refs:
                if symbol[0].startswith(API):
                    checked+=1
                    if not resolve(symbol,defs):failures.add(f'{kind} {symbol[0]}->{symbol[1]}{symbol[2]}')
        # New helpers are legal; overrides of known host API names must match.
        for cls,name,desc in getattr(dex, "virtual_methods", dex.defined_methods):
            if name.startswith('<'):continue
            queue=list(parents.get(cls,[]));seen=set();candidates=[]
            while queue:
                parent=queue.pop()
                if parent in seen:continue
                seen.add(parent);queue.extend(parents.get(parent,[]))
                if parent.startswith(API):
                    candidates.extend(method_index.get((parent,name), []))
            if candidates and not any(m[2]==desc for m in candidates):
                failures.add(f'override {cls}->{name}{desc}')
    return {'checkedReferences':checked,'missingMembers':sorted(failures),'status':'FAIL' if failures else 'PASS'}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--host',required=True,type=Path)
    p.add_argument('extensions',nargs='+',type=Path)
    p.add_argument('--report',type=Path)
    a=p.parse_args();host=load(a.host);reports={}
    for ext in a.extensions:
        reports[ext.name]=verify(host,load(ext))
    text=json.dumps(reports,indent=2);print(text)
    if a.report:a.report.write_text(text+'\n')
    return int(any(r['status']=='FAIL' for r in reports.values()))

if __name__=='__main__':sys.exit(main())
