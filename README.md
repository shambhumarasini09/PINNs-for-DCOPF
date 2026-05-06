# Physucs informed Neural Network for solving DCOPF

Combining physics with deep learning

A physics-informed neural network model for approximating DC Optimal Power Flow (DCOPF) on an IEEE 39-bus system. The project generates synthetic load scenarios, builds a dataset from optimization outputs, and trains a PyTorch model to predict optimal dispatch and related dual variables.

## What is this project?

This repository implements a PINN-style surrogate for DCOPF, using synthetic demand samples and power system data to train a neural network that predicts generator outputs and feasibility indicators.

## Why does it exist?

The goal is to create a fast, data-driven approximation for DCOPF that can be used when repeated optimization solves are too slow. It is motivated by the need to preserve physical constraints while learning from optimization-based labels in power system planning and operational analysis.

## How to run it

1. Open `Project_PINN_main.ipynb` in Jupyter Notebook or Google Colab.
2. Ensure the `Data/` folder is present and contains the CSV files from the generator script.
3. Install required Python packages:
   ```bash
   pip install torch numpy pandas matplotlib scikit-learn tqdm
   ```
4. Run the notebook cells to load data, normalize inputs, train the model, and evaluate predictions.

## What does it do?

- loads DCOPF dataset files from `Data/`
- normalizes demand scenarios and splits data into train/test sets
- defines and trains a PyTorch PINN that predicts both generator outputs and dual variables
- embeds KKT-based physical constraints into the training loss
- evaluates test performance using loss, feasibility, stationarity, and complementary slackness metrics
- checks generator, line flow, and power balance violations under a 1% tolerance
- plots training loss and compares average predicted vs reference generator outputs

## Why PINN instead of a standard neural network?

Traditional supervised ML models learn only from label data and can produce infeasible OPF solutions because they do not explicitly enforce physical laws. In contrast, this PINN includes constraint residuals from KKT optimality conditions during training, which helps the model learn solutions that are both accurate and more physically consistent.

The report shows that the physics-informed model significantly reduces constraint violations compared with a purely supervised baseline:

- generator capacity violation magnitude down by about 82.8%
- line flow violation magnitude down by about 76.4%
- power balance mismatch magnitude down by about 56.5%

These improvements mean the PINN is less likely to predict operating points that would violate generator limits, thermal line ratings, or energy balance.

## Project Structure

- `Project_PINN_main.ipynb` - notebook with data loading, model definition, training, and evaluation.
- `PINNs for DCOPF report.pdf` - project report with result tables, violation analysis, and discussion.
- `Data/` - generated dataset files used by the notebook.
- `Data generation script/datageneration.m` - MATLAB script that produces the dataset using Latin Hypercube Sampling and OPF solves.

## Data Folder Contents

The `Data` folder contains the CSV files used for training and evaluation.

- `PTDF.csv` - Power Transfer Distribution Factors matrix mapping bus injections to line flows.
- `demands_loadbus.csv` - Load scenario samples for the load buses. Each row is one demand case.
- `cost_coeffs.csv` - Generator cost coefficients for the quadratic cost function.
- `line_limits.csv` - Branch flow limits for the DC power flow model.
- `targets.csv` - Target output values for supervised PINN training.

## Generated Output

The model learns from `targets.csv`, which encodes DCOPF solution variables such as:

- optimal generator outputs (`pg`)
- dual variables for system balance (`lambda`)
- line constraint multipliers (`mu3`, `mu27`)
- generator limit multipliers (`tau`)

The notebook evaluates how well the surrogate approximates both the dispatch decisions and the underlying physics-based feasibility conditions.

## Notes

- `Data generation script/datageneration.m` produces the dataset from the `case39` power system and uses YALMIP for solving the OPF problem.
- The notebook includes physics-aware metrics and violation checks to ensure the learned model respects operational constraints.

## Results and Discussion

The notebook and the project report together describe a complete training and evaluation pipeline. The key outcomes include:

- training loss convergence over 2,500 epochs
- test metrics for output accuracy, stationarity residuals, primal feasibility, dual feasibility, and complementary slackness
- violation counts and MW magnitudes for generator capacity, line flow, and power balance under realistic tolerances
- comparison of average predicted and true generator dispatch across the test set

The report emphasizes that embedding KKT-based physics makes the surrogate much more reliable than a standard supervised model. In the experiments, the physics-informed training reduced violation magnitudes by roughly 82.8% for generator capacity, 76.4% for line-flow constraints, and 56.5% for power-balance mismatch.

That means this model is not just learning to match labels; it is learning to respect the underlying physical and operational constraints of the system.
