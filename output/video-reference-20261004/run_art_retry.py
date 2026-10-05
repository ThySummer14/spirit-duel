import importlib.util, sys
spec = importlib.util.spec_from_file_location("botcf_gen", "/Users/thysummer/.agents/skills/botcf-image/scripts/botcf-gen.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
original_post = module.api_post
def longer_post(path, key, body, timeout=300):
    return original_post(path, key, body, timeout=900)
module.api_post = longer_post
sys.argv = ["botcf-gen.py", "--prompts-file", "output/video-reference-20261004/art-retry-prompts.txt", "--name", "灵枢环境美术补跑", "--size", "1536x1024"]
module.main()
