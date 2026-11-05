# Copy-paste Prompts — Telix Workshop Day 2
# Research with an AI Agent in Antigravity

Paste each block into the Antigravity chat panel. Ensure the model selector is set to **Gemini 3.8 Flash (Low thinking)**.

---

## Module 0 — Environment Check

```text
Run setup/preflight.sh and summarise the result in 3 lines. If anything FAILS, fix it.
```

---

## Module 1 — Know the Target

### 1.1 Target biology & structural confidence

```text
Using the DeepMind Science Skills:
1. Fetch the UniProt entry for human HER2 (ERBB2, accession P04626): report recommended name, cellular location, and primary biological role.
2. In AlphaFold DB, look up the structural prediction for P04626: report the overall global pLDDT score and the percentage of very high confidence vs. low confidence regions.
Save your summary as reports/module1_her2_target.md and list the science skills used.
```

---

## Module 2 — Plan Before Acting

### 2.1 Requirements interview & plan formulation

```text
I want to perform a candidate developability and structural binding check for the antibody trastuzumab targeting HER2 (P04626).
Before executing any tools, interview me with 3 multiple-choice questions, one at a time, to confirm:
1. The structural complex source to analyze (experimental PDB structure vs. predictive model).
2. The key sequence liabilities of interest (deamidation, isomerization, oxidation, free cysteines).
3. The preferred format for the resulting summary report.
After I answer all three questions, formulate a structured execution plan and wait for my approval.
```

### 2.2 Approve the plan

```text
Proceed with the plan.
```

---

## Module 3 — The Antibody in 3D & Developability

### 3.1 3D binding complex & contact residues

```text
Using the Science Skills (PDB and PyMOL):
1. Fetch the experimental complex structure for PDB ID 1N8Z (trastuzumab Fab complexed with the extracellular domain of HER2).
2. Identify the Heavy chain (chain B), Light chain (chain A), and HER2 antigen (chain C).
3. Annotate the six Complementarity Determining Regions (CDR loops: H1, H2, H3, L1, L2, L3).
4. Measure the binding interface: list which HER2 residues are in close contact (within 4.0 Angstroms) of the antibody paratope.
5. Using the PyMOL skill, generate an image showing the HER2 antigen surface and highlighting the antibody CDR loops in distinct colors. Save the image to reports/images/1n8z_binding_interface.png.
Save the detailed breakdown to reports/module3_antibody_binding.md and list the science skills used.
```

### 3.2 Sequence stability & chelator conjugation check

```text
Using the sequence extracted from PDB 1N8Z:
1. Scan both the Heavy and Light chains for sequence liabilities:
   - Deamidation motifs (Asn-Gly 'NG', Asn-Ser 'NS')
   - Aspartate isomerization motifs (Asp-Gly 'DG', Asp-Ser 'DS')
   - Oxidation-prone Methionines ('M') or Tryptophans ('W')
   - Unpaired Cysteines
2. Identify which identified liabilities fall directly inside a CDR binding loop versus the structural framework.
3. Identify surface Lysine ('K') residues: flag whether any Lysines are located inside or immediately adjacent to CDR loops where non-specific chelator conjugation could disrupt target binding.
4. Add developability notes explaining how radiation-induced oxidation (radiolysis) during isotope labeling affects formulation strategies.
Append these findings to reports/module3_antibody_binding.md.
```

### Stretch Exercise — Memory vs. Grounded Skills

```text
Without using any tools or reading existing report files, tell me from memory:
What are the exact residue numbers on HER2 that form contact pairs with the CDR-H3 loop in PDB 1N8Z?
Compare your answer with the verified data in reports/module3_antibody_binding.md and evaluate the risk of relying on ungrounded AI memory for molecular design.
```

---

## Module 4 — Test in Gemini Enterprise

In the Gemini Enterprise app, open **New chat → Agents tab → select *Telix Antibody First-Pass*** and ask:

```text
Summarize the binding interface and developability liabilities for the antibody in PDB 1N8Z targeting HER2. Include key contact regions and chelator conjugation considerations.
```
