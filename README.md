# 1000BASE-T PCS TX UVM Verification Environment

A complete UVM/SystemVerilog testbench for the 1000BASE-T (Gigabit Ethernet) PCS transmit encoder, per IEEE Std 802.3-2012 Clause 40.

## What it covers

The encoder pipeline modeled and checked end-to-end:

| Stage | Spec section | Class in golden model |
|-------|--------------|-----------------------|
| Side-stream scrambler (master/slave polynomials) | 40.3.1.3.2 | `step_scrambler()` |
| XOR data scrambler & Sd_n[8] parity bit | 40.3.1.3.3 | `xor_scrambler()` |
| Auxiliary bits Sx_n / Sy_n / Sg_n | 40.3.1.3.5 | `gen_sxsysg()` |
| Convolutional encoder (rate 2/3 trellis) | 40.3.1.3.6 | `step_conv_encoder()` |
| 4D-PAM5 bit-to-symbol mapper (Tables 40-1 / 40-2) | 40.3.1.3.7 | `bit_to_symbol()` |
| Sign randomizer / DC balance (Srev_n) | 40.3.1.3.4 | `sign_randomize()` |

## Architecture

The diagram you provided maps directly to the file structure:

```
                      ┌──────────────────────────────────────┐
                      │   Verification - all members          │
                      │   ┌──────────────┐  ┌──────────────┐  │
                      │   │ Golden PAM5  │  │ Scoreboard / │  │
                      │   │   Model      │──│ Coverage     │  │
                      │   └──────────────┘  └──────────────┘  │
                      └──────────────────────────────────────┘
                              ▲                      ▲
                              │                      │
        ┌─────────────────────┴────┐    ┌────────────┴───────────┐
        │ GMII (input) agent       │    │ State / error-inj agent │
        │ • driver, monitor,       │    │ • driver forces cs_n,   │
        │   sequencer, items       │    │   scr_n, srev_n         │
        └──────────────────────────┘    └─────────────────────────┘
                              │                      │
                              ▼                      ▼
                          ┌──────────────────────────────┐
                          │            DUT               │
                          │  pcs_tx_dut_stub (replace)   │
                          └──────────────────────────────┘
                                       │
                                       ▼
                          ┌──────────────────────────────┐
                          │ PAM5 (passive) agent         │
                          │ • monitor only               │
                          └──────────────────────────────┘
```

## Directory layout

```
pcs_tx_uvm/
├── README.md                       (this file)
├── rtl/
│   └── pcs_tx_dut_stub.sv          REPLACE with your encoder RTL
├── tb/
│   ├── pcs_tx_if.sv                interface + clocking blocks + asserts
│   ├── pcs_tx_pkg.sv               master UVM package
│   ├── tb_top.sv                   clock/reset/DUT/run_test
│   ├── components/
│   │   ├── pcs_tx_golden_model.sv  Clause 40 reference encoder
│   │   ├── gmii_*                  GMII input agent
│   │   ├── pam5_*                  PAM5 output (passive) agent
│   │   ├── state_*                 Error-injection agent
│   │   ├── pcs_tx_scoreboard.sv    Predictor + checker
│   │   └── pcs_tx_coverage.sv      Functional covergroups
│   ├── env/
│   │   └── pcs_tx_env.sv
│   ├── sequences/
│   │   ├── gmii_idle_seq.sv
│   │   ├── gmii_packet_seq.sv
│   │   ├── gmii_protoviol_seq.sv   GMII protocol violations
│   │   ├── gmii_random_seq.sv
│   │   └── error_inject_seq.sv     EI_FORCE_CS / SCR / SREV / BITFLIP
│   └── tests/
│       ├── pcs_tx_base_test.sv
│       ├── pcs_tx_smoke_test.sv    1 packet sanity
│       ├── pcs_tx_random_test.sv   mixed packets + violations
│       └── pcs_tx_error_test.sv    full error-injection campaign
└── sim/
    ├── filelist.f
    └── Makefile                    VCS / Questa / Xcelium targets
```

## Running

```bash
cd sim
make smoke                      # quick sanity check
make random                     # mixed traffic
make error                      # error-injection
make SIM=questa  smoke          # other simulators
make SIM=xcelium random
make WAVES=1     smoke          # dump VCD
make SEED=12345  smoke          # deterministic seed
```

## Error-injection scenarios exercised

| Test | Mechanism | What it proves |
|------|-----------|----------------|
| `EI_FORCE_CS` | `force_cs_en` overrides `cs_n` for N cycles | Convolutional state checking is wired up; coverage hit |
| `EI_FORCE_SCR` | `force_scr_en` overrides scrambler register | Scrambler integrity checking works |
| `EI_FORCE_SREV` | `force_srev_en` overrides sign-reversal toggle | DC-balance / sign logic checking works |
| `EI_BITFLIP` | Output symbol mutation, **no** scoreboard grace | Scoreboard ITSELF is alive — must report mismatches |
| `gmii_protoviol_seq` | Illegal `tx_er`/`tx_en` combos, mid-preamble glitches | Encoder doesn't lock up on bad GMII inputs |

The `pcs_tx_error_test` runs all four EI flavors plus protocol violations in one campaign and reports `Scoreboard caught N injected mismatches`.

## How to integrate your real DUT

1. Drop your RTL into `rtl/`, replacing `pcs_tx_dut_stub.sv`.
2. Match the port list shown in `pcs_tx_dut_stub.sv` (GMII in, PAM5 out, debug probes, force/override pins).
3. If your encoder doesn't expose `force_*` overrides natively, you have two options:
   - Add the override muxes in your RTL (cleanest).
   - Use hierarchical `force` / `release` from `tb_top` against the internal nets — replace the bodies of `state_driver::run_phase` cases accordingly.
4. Verify the polynomial taps and Sx/Sy/Sg formulas in `pcs_tx_golden_model.sv` against the IEEE 802.3 PDF you uploaded — these are the parts most likely to disagree across implementations.

## What you'll need to tune

The golden model is structurally complete but a few details depend on the exact reading of Clause 40 your team has standardized on:

- **Bit-to-symbol pair → quinary mapping** (`sym_from_pair()` in the golden model). The mapping in Table 40-1/40-2 has multiple compatible representations; pick the one your RTL uses and update.
- **Convolutional encoder next-state equation** in `step_conv_encoder()`. The trellis structure is fixed by the standard but vendors differ on bit-numbering of `cs_n`.
- **Auxiliary-bit polynomials** in `gen_sxsysg()`. Verify the bit indices.

Each of these has a comment in the source pointing to the relevant section.

## Asks for me when you have your real DUT

- Your encoder's exact internal register names so the white-box probes line up.
- Whether `loc_rcvr_status` and master/slave config are pin-strapped or register-controlled.
- Pipeline depth from GMII-in to PAM5-out (set via `pipeline_depth` config in `pcs_tx_scoreboard`, default 4).
