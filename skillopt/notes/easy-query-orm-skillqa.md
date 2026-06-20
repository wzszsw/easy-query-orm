# Easy Query ORM SkillQA

Use `configs/skillqa/easy-query-orm-mimo-fast.yaml` for the fast optimization loop.

It keeps the run close to the previous successful recipe:

- `num_epochs=1`
- auto `train_size` from the split
- `batch_size=25`
- `analyst_workers=2`
- `workers=2`
- `failure_only=true`
- `learning_rate=2`
- `min_learning_rate=2`
- `use_slow_update=false`
- `use_meta_skill=false`
- `use_gate=true`
- `eval_test=false`

Recommended command:

```powershell
$env:QWEN_CHAT_API_KEY = "<your-key>"
python scripts/train.py --config configs/skillqa/easy-query-orm-mimo-fast.yaml --qwen_chat_base_url https://api.xiaomimimo.com/v1
```

Why this config exists:

- the default `easy-query-orm-mimo.yaml` is a broader exploration profile
- the fast profile is the stable rerun profile for quick skill iteration
- `train_size: 0` avoids hard-coding the split size after the question bank grows
