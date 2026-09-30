"""Launcher safety/config tests: mocked GPU and binary; no model is loaded."""
import fcntl
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='ninfer-launcher-test-')
        self.addCleanup(self.temp.cleanup)
        self.root=pathlib.Path(self.temp.name)
        (self.root/'scripts').mkdir()
        self.script=self.root/'scripts/serve_ninfer_256k.sh'
        shutil.copy2(pathlib.Path(__file__).with_name(self.script.name),self.script)
        self.model=self.root/'model.ninfer'; self.model.touch()
        mockbin=self.root/'mockbin'; mockbin.mkdir()
        gpu=mockbin/'nvidia-smi'
        gpu.write_text('#!/usr/bin/env python3\nimport os,sys\n'
            'print(os.environ.get("MOCK_FREE_MIB","31000") if any("memory.free" in x for x in sys.argv) '
            'else "GPU-test-5090, NVIDIA GeForce RTX 5090")\n')
        gpu.chmod(0o755)
        binary=mockbin/'ninfer-serve'
        binary.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
            'print(json.dumps({"args":sys.argv[1:],"gpu":os.environ.get("CUDA_VISIBLE_DEVICES")}))\n')
        binary.chmod(0o755)
        self.env={k:v for k,v in os.environ.items() if not k.startswith('NINFER_')}
        self.env.update(PATH=str(mockbin)+':'+self.env['PATH'],
                        NINFER_BINARY=str(binary),NINFER_MODEL=str(self.model))

    def run_launcher(self,*args):
        return subprocess.run(['bash',str(self.script),*args],env=self.env,
                              text=True,capture_output=True,timeout=10)

    def test_default_mtp3_full_context(self):
        p=self.run_launcher();self.assertEqual(p.returncode,0,p.stderr)
        result=json.loads(p.stdout.splitlines()[-1]);args=result['args']
        self.assertEqual(result['gpu'],'GPU-test-5090')
        for flag,value in (('--draft-tokens','3'),('--max-context','262144'),
                           ('--kv-capacity','262144'),('--max-concurrency','1'),
                           ('--kv-dtype','k8v4'),('--host','127.0.0.1')):
            self.assertEqual(args[args.index(flag)+1],value)
        self.assertIn('--no-thinking',args);self.assertIn('--no-prefix-reuse',args)

    def test_mtp2_and_baseline(self):
        for profile in ('mtp2','baseline'):
            p=self.run_launcher(profile,'18088');self.assertEqual(p.returncode,0,p.stderr)
            args=json.loads(p.stdout.splitlines()[-1])['args']
            self.assertEqual(args[args.index('--port')+1],'18088')
            if profile=='mtp2':self.assertEqual(args[args.index('--draft-tokens')+1],'2')
            else:self.assertNotIn('--spec',args)

    def test_insufficient_memory_does_not_launch(self):
        self.env['MOCK_FREE_MIB']='16000'
        p=self.run_launcher();self.assertEqual(p.returncode,3)
        self.assertIn('No process was stopped',p.stderr)

    def test_invalid_arguments(self):
        for args in (('invalid',),('mtp3','0'),('mtp3','65536'),('mtp3','abc')):
            self.assertEqual(self.run_launcher(*args).returncode,2)

    def test_missing_model(self):
        self.env['NINFER_MODEL']=str(self.root/'absent.ninfer')
        self.assertEqual(self.run_launcher().returncode,2)

    def test_pause_prevents_launch(self):
        (self.root/'PAUSED').touch()
        self.assertEqual(self.run_launcher().returncode,3)

    def test_shared_lock_prevents_launch(self):
        lock=self.root/'shared.lock';self.env['NINFER_LOCK_FILE']=str(lock)
        with lock.open('w') as f:
            fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
            self.assertEqual(self.run_launcher().returncode,3)


if __name__=='__main__':unittest.main()
