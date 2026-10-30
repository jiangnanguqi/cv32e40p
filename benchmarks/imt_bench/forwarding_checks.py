#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Validate the generated no-forwarding experiment without editing upstream RTL.

First prepare/build software using port.py. This command reuses those images;
--suite additionally runs all 19 Embench programs and Tiny on the chosen RTL.
"""
import argparse,concurrent.futures,json
from pathlib import Path
import port,build_sim

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--build-dir',type=Path,required=True)
 p.add_argument('--riscv-tools',default='riscv64-unknown-elf')
 p.add_argument('--verilator',default='verilator')
 p.add_argument('--forwarding',type=int,choices=[0,1],default=0)
 p.add_argument('--jobs',type=int,default=2)
 p.add_argument('--run-jobs',type=int,default=3)
 p.add_argument('--timeout',type=float,default=1800)
 p.add_argument('--suite',action='store_true')
 a=p.parse_args();a.build_dir=a.build_dir.resolve();a.gsf=1
 c=json.loads((a.build_dir/'config.json').read_text());c['cv_forwarding']=a.forwarding
 sim=build_sim.build(port.HERE,a.build_dir/('sim-fw'+str(a.forwarding)),a.verilator,a.jobs,'small',a.forwarding)
 folder=a.build_dir/'embench/forwarding-hazards';folder.mkdir(parents=True,exist_ok=True)
 obj=port.compile_c(a,port.HERE/'forwarding_hazards.c',folder/'hazards.o',
                    [*port.RV,'-O3','-std=gnu99','-ffreestanding'])
 objects=port.common_objects(a,folder,False);elf=folder/'forwarding-hazards.elf'
 port.command([a.riscv_tools+'-gcc',*port.RV,'-static','-nostartfiles','-T',port.HERE/'link.ld',
               '-Wl,--gc-sections',obj,*objects,'-Wl,--start-group','-lc','-lm','-lgcc','-Wl,--end-group','-o',elf])
 meta=dict(name='forwarding-hazards',workload='smoke',gsf=1,**port.convert(a,elf))
 results=[port.run_one(a,'forwarding-hazards',meta,sim,c)]
 if results[0]['passed'] and a.suite:
  if len(c['targets'])!=20:raise RuntimeError('Full suite requires 19 Embench targets and Tiny')
  def run(pair):
   name,meta=pair
   elf=a.build_dir/('tiny/tiny.elf' if name=='tiny' else 'embench/'+name+'/'+name+'.elf')
   if port.digest(elf.with_suffix('.bin'))!=meta['binary_sha256']:raise RuntimeError('Binary metadata mismatch: '+name)
   return port.run_one(a,name,meta,sim,c)
  with concurrent.futures.ThreadPoolExecutor(max_workers=a.run_jobs) as pool:
   results+=list(pool.map(run,c['targets'].items()))
 summary=dict(passed=all(r['passed'] for r in results),forwarding=a.forwarding,results=results)
 port.write(a.build_dir/('forwarding-fw'+str(a.forwarding)+'-summary.json'),json.dumps(summary,indent=2)+'\n')
 if not summary['passed']:raise SystemExit(1)

if __name__=='__main__':main()
