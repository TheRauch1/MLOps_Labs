# Lecture 05 — Testing: Study Guide

**TSM_MachLeData | FS 2026 | Dr. Frank-Peter Schilling (ZHAW) & Vanni Galli (SUPSI)**

This guide brings you fully up to speed on the lecture you missed and walks you through all four parts of Lab 04 end-to-end, including how to run GitHub Actions locally using Docker + `act`.

---

## Part 1 — Theory

The lecture covers three big topics: **Software Testing**, **Automation (CI/CD)**, and **Testing ML Systems**. Let's go through each in depth.

---

### 1.1 Why is Testing ML Systems Different?

Before diving in, the lecture makes a crucial observation. Normal software is just code — written by humans, it fails loudly (crashes, exceptions), and is relatively static. An ML system is **code + data**: the model is "compiled" by an optimizer to satisfy a proxy metric, it fails *silently* (wrong predictions with no errors), and it changes constantly as data and models evolve.

This has important consequences. A good test score on your held-out test set tells you far less than you think, because:

- Production data distribution may not match your test data (**data drift / distribution shift**).
- A single average metric hides how the model performs on subgroups (**slices**).
- You may be optimizing for a proxy metric that doesn't reflect what the business actually cares about.
- "Expected performance does not tell the whole story" — edge cases, long-tail distributions, and rare inputs are often missing from training data.

**Common mistakes** teams make: only testing the model (not the whole ML system), not testing the data, not understanding model performance at a granular level, trusting automated tests too much, and assuming offline testing is sufficient.

---

### 1.2 Software Testing

#### Test Types

There are three levels of tests, forming the classic **test pyramid**:

**Unit tests** check a single function or class in isolation. They should be fast, numerous, and the backbone of your test suite.

**Integration tests** check that two or more components work correctly *together* — for example, that your model works with your preprocessing function.

**End-to-end (E2E) tests** check the entire system path with real-like inputs. These are slow and expensive, so there should be far fewer of them.

The pyramid principle: `N(unit) >> N(integration) >> N(E2E)`. Don't invert this — an end-to-end heavy test suite is slow, brittle, and hard to debug.

#### Best Practices

- **Automate** your tests with CI/CD (see next section).
- Make tests **reliable and fast**, and put them through the same code review as production code.
- **Enforce** that tests must pass before merging to main.
- When a production bug is found, **write a test for it** — so it can never silently creep back.
- Think of your test suite as a **classifier**: it predicts whether a commit has a bug. Like any classifier, you want few missed alarms (failing to catch real bugs) and few false alarms (failing good code).

#### Test Coverage and TDD

**Test coverage** measures what percentage of your code is exercised by at least one test. It's a useful signal but doesn't measure test *quality*. The tool is [Codecov](https://about.codecov.io/).

**Test-driven development (TDD)** is the practice of writing tests *before* writing the code they test. The tests then act as a specification. Not universally adopted, but a powerful discipline.

#### Tools for Python

- **pytest** — the standard tool. Supports separate test suites, shared resources (fixtures), and parametrized test variations. `pytest` discovers any file named `test_*.py` or `*_test.py`. See Lab Part 2.
- **doctest** — embed tiny tests directly in function docstrings (great for documentation that stays honest).
- **black** — auto-formats Python code to a consistent style.
- **flake8** — checks for style violations, unused imports, missing docstrings, and type hint issues.
- **shellcheck** — lints bash scripts, explaining weird edge cases.

**Linting** is the practice of flagging suspicious code — stylistic errors, non-adherence to conventions, potential logical errors. Reasons: avoids bugs, ends style arguments, reduces noise in diffs.

#### pre-commit

[pre-commit](https://pre-commit.com/) is a framework for running linting, formatting, and other hygiene checks automatically on every `git commit`. It runs as a **git hook**, keeps itself in a separate environment from your dev env, and integrates easily with GitHub Actions. The key constraint: keep total pre-commit runtime to a few seconds, or it discourages people from committing.

---

### 1.3 Automation: CI/CD

**CI (Continuous Integration)** is the practice of frequently merging developer branches into a shared main branch, with automated builds and tests running on every merge. **CD (Continuous Delivery/Deployment)** extends this to automatically deploying validated code.

The key idea: **automate your tests and connect them to your version control system**. This reduces friction when reproducing errors (the test is always tied to a specific commit state) and lets tests run in parallel with other development work.

#### GitHub Actions

GitHub Actions is the dominant CI/CD tool for projects hosted on GitHub. You define workflows as YAML files stored in `.github/workflows/`. A workflow:

- Is triggered by **events** (push, pull request, issue opened, schedule, etc.)
- Consists of one or more **jobs** (which can run in parallel or sequentially)
- Each job runs on a **runner** (a fresh virtual machine — Ubuntu, Windows, or macOS)
- Each job has **steps** that either run a shell command (`run:`) or invoke a reusable **Action** (`uses:`)

Here's the anatomy of a simple workflow YAML:

```yaml
name: My Workflow          # Shown in GitHub UI
on:                        # What triggers this workflow
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:                   # Job name (arbitrary)
    runs-on: ubuntu-latest # Which runner to use
    steps:
      - uses: actions/checkout@v4          # Check out your code
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Run tests
        run: |
          pip install -r requirements.txt
          pytest
```

The `${{ secrets.GITHUB_TOKEN }}` syntax lets you access secret environment variables stored securely in your repo settings.

#### Other CI/CD systems

- **Jenkins** — self-hosted, very flexible, good when you need your own GPUs.
- **CircleCI**, **TravisCI**, **Buildkite** — cloud-hosted alternatives.

---

### 1.4 Testing ML Systems — The Full Taxonomy

The lecture maps different test types onto the parts of the ML system they cover. The ML system has: **Storage/Preprocessing → Training System → ML Model → Prediction System → Serving System → Production Data → Labeling System** (a feedback loop).

Here is every test type and where it sits:

#### Infrastructure Tests
**What:** Unit tests for training code.
**Goal:** Catch bugs in your training pipelines before they silently corrupt results.
**How:** Unit test training code like any other code. Add "single batch" or "single epoch" tests that verify loss decreases on a tiny dataset. Run frequently during development.

#### Training Tests
**What:** Integration tests between your data system and your training system.
**Goal:** Ensure training is **reproducible**.
**How:** Pull a fixed (versioned) dataset, run a full or abbreviated training run, check that model performance stays consistent. Run these periodically (e.g. nightly).

#### Functionality Tests
**What:** Unit tests for prediction/inference code.
**Goal:** Avoid regressions in the code that wraps your model.
**How:** Unit test prediction code like any other code. Load a pre-trained model and test inference on a small set of key examples. Run frequently.

#### Evaluation Tests ← *the heart of ML testing*
**What:** Integration tests between training system and prediction code.
**Goal:** Ensure a new model is ready for production.
**How:** Evaluate on all metrics, datasets, and slices you care about. Compare the new model to the previous one and to baselines. Understand the **performance envelope** — where the model performs well and where it doesn't. Run every time a candidate model is created.

What "all metrics" means in practice:
- **Model metrics**: precision, recall, accuracy, L2, etc.
- **Behavioral metrics**: does the model behave consistently (e.g. monotonically) when you perturb inputs in expected ways?
- **Robustness metrics**: how does it hold up under noise, adversarial examples?
- **Privacy and fairness metrics**

**High-loss examples:** Collect the data points your model struggles most with and put them in a "hard" test suite. Note: the problem may be in the model *or* in the data (mislabeled examples).

**Slice-based evaluation:** Performance varies across subgroups. For website traffic data, you'd slice by gender, mobile vs. desktop, browser, location, etc. Focusing only on overall accuracy can hurt performance on critical subgroups — and even conceal it entirely (see **Simpson's Paradox**: an aggregate trend can reverse when you slice by a confounding variable).

**When to pass evaluation tests:** Compare new model vs. previous model AND a fixed older baseline model. Set thresholds on the diffs between models on most metrics and across slices. The fixed older baseline catches "slow leak" regressions that accumulate over many small model updates.

#### Shadow Tests
**What:** Integration tests between prediction system and serving system.
**Goal:** Detect bugs that only appear on live production data, or inconsistencies between the offline and online model.
**How:** Run the new model in production infrastructure but *don't return its predictions to users* — just log them. Compare prediction distributions of old vs. new model, and offline vs. online, for inconsistencies.

#### A/B Tests
**What:** Live tests of user reaction to the new model.
**Goal:** Understand how the new model affects real user and business metrics.
**How:** Route a small fraction of traffic to the new model ("canarying"), gradually increase it, compare business metrics on the two cohorts. Use statistically principled splits.

**Canary Deployment** is the pattern of rolling out a new model to a small fraction of users first (e.g. Austria, then Europe, then the world), watching for problems, before full rollout.

#### Labeling Tests
**What:** Tests on your labeling system.
**Goal:** Catch poor-quality labels before they corrupt training.
**How:** Train and certify labelers, aggregate labels from multiple labelers, assign "trust scores", spot-check labels manually, run a previous model on new labels and inspect disagreements.

#### Expectation Tests (Data Tests)
**What:** Unit tests for data.
**Goal:** Catch data quality issues before they enter your pipeline.
**How:** Define rules ("expectations") about properties of each data table at each stage of preprocessing (e.g. "this column must not be null", "values must be in range [0, 1]"). Run these in your batch data pipeline.
**Tool:** [Great Expectations](https://greatexpectations.io/) — you define expectations manually or by profiling a known-good dataset.

#### Bonus: Formal Verification
Testing *cannot* guarantee properties — it can only fail to find violations. Formal verification can mathematically *prove* that a neural network satisfies a property (like adversarial robustness) for *all* inputs in a specified region.

**Problem formulation:** Given network N, a pre-condition φ (an input region, e.g. an ε-ball around an image), and a post-condition ψ (e.g. label doesn't change), prove that for all inputs satisfying φ, the output satisfies ψ.

Two key concepts:
- **Soundness:** A method is sound if it only claims a property holds when it truly does. Tests are unsound — they miss violations.
- **Completeness:** A method is complete if it can always prove a property that actually holds.

**Bound propagation (incomplete but sound):** Track an over-approximation (e.g. a box/interval for each pixel) through the network. If the post-condition holds for the over-approximation, it holds for all inputs in the region. Fast but may fail to verify properties that actually hold.

**MILP encoding (complete and sound but expensive):** Encode the neural network as a Mixed-Integer Linear Program. Can always give an answer but is NP-complete — only feasible for small networks.

---

### 1.5 Summary

The lecture closes with a clear takeaway slide:

- Test **each part of the ML system**, not just the model.
- Test **code, data, and model performance**, not just code.
- Testing model performance is **an art, not a science** — intuition matters.
- The goal is to build a **granular understanding** of where your model performs well and where it doesn't.

Google published a practical checklist called the [ML Test Score](https://research.google/pubs/pub46555/) covering 28 specific tests across Data, Model, ML Infrastructure, and Monitoring categories — worth bookmarking.

---

## Part 2 — Lab 04 Overview

The lab has four parts. Here's the map:

```
lab04/
├── 01_introduction_to_cicd.md      ← Part 1: GitHub Actions + act
├── 02_introduction_to_pytest.md    ← Part 2: pytest unit testing
├── 03_testing_models.md            ← Part 3: Deepchecks + CML + SkyPilot
├── 04_verifying_models.md          ← Part 4: Formal verification (bonus)
│
├── github_actions_intro/
│   ├── workflows/
│   │   └── python_demo.yaml        ← Starting workflow to run with act
│   └── requirements.txt
│
├── pytest/
│   └── test_answer.py              ← Starting point for pytest exercises
│
├── deepchecks_intro/
│   ├── data.py                     ← Downloads hymenoptera (ants/bees) dataset
│   ├── train.py                    ← Trains a ResNet classifier
│   ├── test.py                     ← Runs deepchecks model_evaluation suite
│   └── workflows/
│       └── deepchecks.yaml         ← TODO: fill this in as an exercise
│
├── deepchecks_advanced/
│   ├── check_attack.py             ← TODO: implement FGSM adversarial check
│   ├── check_attack_solution.py    ← Reference solution
│   ├── test.py                     ← TODO: use your custom check here
│   └── test_solution.py            ← Reference solution
│
├── verification/
│   ├── box_transformer.ipynb       ← TODO: implement box propagation
│   └── box_transformer_solution.ipynb
│
└── env.yaml                        ← Conda environment (Python 3.11)
```

---

## Part 3 — Running GitHub Actions Locally with `act` + Docker

The lab uses `act` instead of pushing to GitHub, so you can test your workflows locally without needing a GitHub account or internet connection.

### How `act` works

`act` reads your workflow files from `.github/workflows/` (or any directory you point it at), uses Docker to spin up containers that mimic GitHub's runners, and executes the steps inside those containers. The environment variables and filesystem match what GitHub provides.

### Installation

**Step 1: Install Docker**

If you don't have Docker installed, get Docker Desktop from [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/). Make sure Docker is running before using `act`.

**Step 2: Install `act`**

Follow the instructions at [https://nektosact.com/installation/index.html](https://nektosact.com/installation/index.html). The quickest options:

```shell
# macOS (Homebrew):
brew install act

# Windows (winget):
winget install nektos.act

# Linux (curl):
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

**Step 3: First run — select container size**

The first time you run `act`, it will ask which container image size to use. **Select "Medium"** (the `catthehacker/ubuntu:act-*` image). The "Large" image is multi-GB and unnecessary; "Micro" is missing many tools.

### Running the demo workflow

The lab provides a helper script `./bin/act` but you can also use the globally installed `act`. To run the Python demo workflow:

```shell
# From inside the lab04 directory:
act push -W github_actions_intro/workflows

# Or with the provided helper (if bin/act exists):
./bin/act push -W github_actions_intro/workflows
```

The `push` argument simulates a `git push` event — this matches the `on: [push]` trigger in the workflow YAML.

**On Apple Silicon (M1/M2/M3)**, you must add an extra flag because the Docker containers are built for AMD64:

```shell
act push -W github_actions_intro/workflows --container-architecture linux/amd64
```

### Running the deepchecks workflow (Part 3 of lab)

Once you've written the deepchecks workflow, run it with:

```shell
act push -W deepchecks_intro/workflows
```

### Key `act` flags to know

| Flag | Meaning |
|------|---------|
| `push` / `pull_request` | Simulates that event type |
| `-W <path>` | Path to the workflows directory |
| `--container-architecture linux/amd64` | Required on Apple Silicon |
| `-j <job-name>` | Run only a specific job |
| `--list` | List all available workflows/jobs without running |
| `--secret-file .secrets` | Load secrets from a file (for `${{ secrets.X }}`) |

### Why use `act` instead of real GitHub Actions?

Real GitHub Actions require pushing to a GitHub-hosted repo, waiting for a cloud runner, and consuming CI minutes. `act` gives you instant local feedback during development, which is especially useful when iterating on your YAML workflows.

---

## Part 4 — Lab Exercises: What to Do and Why

### Part 1: CI/CD with GitHub Actions

**Goal:** Learn to write and run GitHub Actions YAML workflows.

**Exercise 1:** Modify `github_actions_intro/workflows/python_demo.yaml`. The provided workflow only prints the Python version. Add two steps:
1. Upgrade pip: `python -m pip install --upgrade pip`
2. Install requirements: `python -m pip install -r github_actions_intro/requirements.txt`

Run with:
```shell
act push -W github_actions_intro/workflows
```

**Exercise 2:** After completing the pytest section, write a new workflow that also runs pytest on your test suite.

**Why this matters:** This is the "automate your tests" step from the lecture. Every real MLOps project needs a CI pipeline that runs tests on every push so that no broken code ever silently merges to main.

---

### Part 2: pytest

**Goal:** Learn pytest — fixtures, marks, parametrization, and testing PyTorch code.

**Exercises (in `pytest/test_answer.py`):**

1. **Basic test:** The file already has `test_answer()`. Run `pytest` from the `pytest/` directory to see it pass.

2. **Exception testing:** Add `validate_answer(answer)` that raises `ValueError` if `answer != 42`. Write a test using `pytest.raises`:
   ```python
   def test_validate_answer_raises():
       with pytest.raises(ValueError):
           validate_answer(99)
   ```

3. **Tensor Train Layer:** You are given `TensorTrainLayer`, a custom PyTorch layer. Write a test suite covering:
   - Random inputs of various shapes
   - Various `in_modes`, `out_modes`, and `ranks` combinations
   - Known input-output pairs

   Use `torch.testing.assert_close()` instead of `==` for floating-point comparisons.

4. **Connect to CI:** Write a GitHub Actions workflow that runs your pytest suite automatically.

**Why this matters:** This directly implements "Infrastructure Tests" and "Functionality Tests" from the lecture. These are the most frequent tests you'll write in an ML project.

---

### Part 3: Testing ML Models with Deepchecks

**Goal:** Use Deepchecks to run a model evaluation test suite on a real trained model.

**Step 1 — Train the model:**
```shell
cd deepchecks_intro
python data.py    # Downloads the ants/bees (hymenoptera) dataset
python train.py   # Trains a ResNet binary classifier
```

**Step 2 — Run the test suite:**
```shell
python test.py    # Generates report.html
```
Open `report.html` in your browser. You'll see per-class accuracy, confusion matrix, prediction distribution, and more. The model probably won't be great — that's intentional!

**Step 3 — Write the CI workflow:**
Fill in `deepchecks_intro/workflows/deepchecks.yaml`. Your workflow should run all three scripts (`data.py`, `train.py`, `test.py`) in sequence on every push.

**Step 4 — Advanced: custom adversarial robustness check:**
In `deepchecks_advanced/`, implement the FGSM adversarial attack check in `check_attack.py`. The file has TODO comments guiding you. The check should:
- `initialize_run`: set up tracking variables
- `update`: on each batch, apply FGSM perturbations and compare predictions on clean vs. perturbed images
- `compute`: return the fraction of images whose prediction changed (= the model's vulnerability to the attack)

**Why this matters:** This is "Evaluation Tests" from the lecture. You're testing the full model, not just the code — including slices, performance metrics, and robustness.

---

### Part 4: Formal Verification (Bonus)

**Goal:** Understand that testing can't *prove* correctness — verification can.

**Exercise — `verification/box_transformer.ipynb`:**

Implement **box propagation** (abstract interpretation with interval/box domains) through a small neural network. Given an input interval `[x_lo, x_hi]` for each input feature, propagate bounds through:
- Linear layers: `[W @ x_lo + b, W @ x_hi + b]` (with sign correction for negative weights)
- ReLU: `[max(0, lo), max(0, hi)]`

If the post-condition (e.g. output class doesn't change) holds for the entire box at the output, the network is verified as robust for all inputs in that box.

**Why this matters:** It ties back to the lecture's discussion of soundness and completeness. Testing (adversarial attacks) is *unsound* — it may miss real vulnerabilities. Bound propagation is *sound* but *incomplete* — it may fail to verify things that are actually true. MILP is *sound and complete* but computationally intractable.

---

## Part 5 — Key Terms Cheatsheet

| Term | Meaning |
|------|---------|
| Unit test | Tests one function/class in isolation |
| Integration test | Tests two+ components working together |
| E2E test | Tests the entire system end-to-end |
| Test pyramid | N(unit) >> N(integration) >> N(E2E) |
| Test coverage | % of code lines exercised by tests |
| TDD | Write tests before writing code |
| CI/CD | Automate build, test, deploy on every commit |
| GitHub Actions | CI/CD via YAML workflows in `.github/workflows/` |
| `act` | Local runner that simulates GitHub Actions using Docker |
| pre-commit | Run linting/formatting as a git hook on every commit |
| Lint | Static analysis that flags code style/logic issues |
| black | Auto-formatter for Python |
| flake8 | Python style/bug checker |
| Infrastructure tests | Unit tests for training code |
| Training tests | Integration tests: data system + training system |
| Functionality tests | Unit tests for inference/prediction code |
| Evaluation tests | Full model evaluation on metrics, slices, baselines |
| Shadow tests | New model runs in prod but predictions aren't shown to users |
| A/B tests | Live traffic split between old and new model |
| Canary deployment | Gradual traffic rollout to new model |
| Labeling tests | Quality checks on the labeling system |
| Expectation tests | Data unit tests (Great Expectations) |
| Performance envelope | Where the model is expected to perform well / not |
| Slice-based evaluation | Evaluate model on subgroups to detect hidden bias |
| Simpson's Paradox | Aggregate trend reverses when data is sliced by a confound |
| Deepchecks | Python library for ML model test suites |
| CML | Extends CI/CD pipelines to report ML metrics on commits/PRs |
| SkyPilot | Abstracts cloud infra for launching GPU training jobs |
| FGSM | Fast Gradient Sign Method — an adversarial attack |
| Formal verification | Mathematical proof that a network satisfies a property |
| Soundness | Method only asserts property holds when it truly does |
| Completeness | Method can always prove a property that actually holds |
| Bound propagation | Propagate input interval through network to verify robustness |
| MILP | Mixed-Integer Linear Programming — complete but NP-complete |

---

## Further Reading

- [Jeremy Jordan — Effective Testing for ML](https://www.jeremyjordan.me/testing-ml/)
- [Made With ML — Testing](https://madewithml.com/courses/mlops/testing/)
- [Made With ML — Evaluation](https://madewithml.com/courses/mlops/evaluation/)
- [Google ML Test Score paper](https://research.google/pubs/pub46555/)
- [pytest documentation](https://docs.pytest.org/en/stable/)
- [Deepchecks documentation](https://docs.deepchecks.com/stable/getting-started/welcome.html)
- [act documentation](https://nektosact.com/)
- [Introduction to Neural Network Verification](https://verifieddeeplearning.com/)
