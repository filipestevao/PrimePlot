# LaTeX Labels

PrimePlot renders label text with a KaTeX-compatible LaTeX subset. This guide
covers Greek letters, italic and upright styles, and the other commands that are
useful in axis labels and legend names.

## Enable LaTeX

Click the `$` badge inside a label field. The badge glows while LaTeX is active
for that field.

- **Graph** → **Labels & Titles** → **X Label**, **Y Label**
- **Table** or **Function** → **Identification** → **Display Name** (legend)

Axis labels use the full math renderer. Legend names use a lighter substitution
path, described in [Where LaTeX applies](#where-latex-applies).

For axis labels, the whole field is parsed as LaTeX; `$...$` delimiters are
optional. Legend names do not use `$...$`.

## Quick reference

| Goal | Command |
|:--|:--|
| Italic lowercase Greek | `\alpha` |
| Upright lowercase Greek | `\mathrm{\alpha}` |
| Upright uppercase Greek | `\Gamma` |
| Italic uppercase Greek | `\varGamma` or `\mathit{\Gamma}` |
| Upright word | `\text{max}` |
| Subscript | `x_0` or `x_{max}` |
| Superscript | `x^2` or `10^{-3}` |

## Lowercase Greek

Lowercase Greek is italic by default. Wrap the command in `\mathrm{...}` for an
upright letter.

| Letter | Italic (default) | Upright |
|:---:|:---:|:---:|
| α | `\alpha` | `\mathrm{\alpha}` |
| β | `\beta` | `\mathrm{\beta}` |
| γ | `\gamma` | `\mathrm{\gamma}` |
| δ | `\delta` | `\mathrm{\delta}` |
| ε | `\varepsilon` | `\mathrm{\varepsilon}` |
| ζ | `\zeta` | `\mathrm{\zeta}` |
| η | `\eta` | `\mathrm{\eta}` |
| θ | `\theta` | `\mathrm{\theta}` |
| ι | `\iota` | `\mathrm{\iota}` |
| κ | `\kappa` | `\mathrm{\kappa}` |
| λ | `\lambda` | `\mathrm{\lambda}` |
| μ | `\mu` | `\mathrm{\mu}` |
| ν | `\nu` | `\mathrm{\nu}` |
| ξ | `\xi` | `\mathrm{\xi}` |
| ο | `\omicron` | `\mathrm{\omicron}` |
| π | `\pi` | `\mathrm{\pi}` |
| ρ | `\rho` | `\mathrm{\rho}` |
| σ | `\sigma` | `\mathrm{\sigma}` |
| τ | `\tau` | `\mathrm{\tau}` |
| υ | `\upsilon` | `\mathrm{\upsilon}` |
| φ | `\varphi` | `\mathrm{\varphi}` |
| χ | `\chi` | `\mathrm{\chi}` |
| ψ | `\psi` | `\mathrm{\psi}` |
| ω | `\omega` | `\mathrm{\omega}` |

### Variant forms

Several lowercase letters have alternate forms. They are italic by default and
follow the same `\mathrm{...}` rule for upright output.

| Letter | Italic (default) | Upright |
|:---:|:---:|:---:|
| ϵ | `\epsilon` | `\mathrm{\epsilon}` |
| ε | `\varepsilon` | `\mathrm{\varepsilon}` |
| ϑ | `\vartheta` | `\mathrm{\vartheta}` |
| ϕ | `\phi` | `\mathrm{\phi}` |
| φ | `\varphi` | `\mathrm{\varphi}` |
| ϖ | `\varpi` | `\mathrm{\varpi}` |
| ϱ | `\varrho` | `\mathrm{\varrho}` |
| ς | `\varsigma` | `\mathrm{\varsigma}` |

`\epsilon` produces the lunate ϵ. Use `\varepsilon` for the common ε. Likewise,
`\phi` produces ϕ and `\varphi` produces φ.

## Uppercase Greek

Uppercase Greek is upright by default. Use `\varGamma`-style commands or
`\mathit{...}` for italic output.

| Letter | Upright (default) | Italic |
|:---:|:---:|:---:|
| Γ | `\Gamma` | `\varGamma` or `\mathit{\Gamma}` |
| Δ | `\Delta` | `\varDelta` or `\mathit{\Delta}` |
| Θ | `\Theta` | `\varTheta` or `\mathit{\Theta}` |
| Λ | `\Lambda` | `\varLambda` or `\mathit{\Lambda}` |
| Ξ | `\Xi` | `\varXi` or `\mathit{\Xi}` |
| Π | `\Pi` | `\varPi` or `\mathit{\Pi}` |
| Σ | `\Sigma` | `\varSigma` or `\mathit{\Sigma}` |
| Υ | `\Upsilon` | `\varUpsilon` or `\mathit{\Upsilon}` |
| Φ | `\Phi` | `\varPhi` or `\mathit{\Phi}` |
| Ψ | `\Psi` | `\varPsi` or `\mathit{\Psi}` |
| Ω | `\Omega` | `\varOmega` or `\mathit{\Omega}` |

### Uppercase letters that look Latin

These uppercase Greek letters are identical to Latin letters. Type the Latin
letter; there is no standard `\Alpha`-style math command.

| Greek | Type | Italic |
|:---:|:---:|:---:|
| Α | `A` | `\mathit{A}` |
| Β | `B` | `\mathit{B}` |
| Ε | `E` | `\mathit{E}` |
| Ζ | `Z` | `\mathit{Z}` |
| Η | `H` | `\mathit{H}` |
| Ι | `I` | `\mathit{I}` |
| Κ | `K` | `\mathit{K}` |
| Μ | `M` | `\mathit{M}` |
| Ν | `N` | `\mathit{N}` |
| Ο | `O` | `\mathit{O}` |
| Ρ | `P` | `\mathit{P}` |
| Τ | `T` | `\mathit{T}` |
| Χ | `X` | `\mathit{X}` |

Do not use `\Alpha`, `\Beta`, `\Epsilon`, and similar names in axis labels.
They are not standard math commands.

## Font styles

| Command | Result |
|:--|:--|
| `\mathrm{...}` | Upright, using the label's text font |
| `\mathit{...}` | Italic, using the math italic font |
| `\text{...}` | Upright text; spaces are preserved |
| `\Gamma` | Upright uppercase (default) |
| `\varGamma` | Italic uppercase shorthand |

Use `\mathrm{d}` for an upright differential d, and `\mathit{x}` for an italic
variable x.

## Subscripts and superscripts

Use `_` for subscripts and `^` for superscripts. Wrap multi-character scripts in
braces.

| Input | Result |
|:--|:--|
| `x_0` | x with subscript 0 |
| `x_{max}` | x with subscript max |
| `x^2` | x squared |
| `10^{-3}` | 10 to the power −3 |
| `\alpha_0` | italic α with subscript 0 |
| `\mathrm{\alpha}_{max}` | upright α with subscript max |

## Examples

| Label text | Result |
|:--|:--|
| `\alpha` | Italic α |
| `\mathrm{\alpha}` | Upright α |
| `\mathit{\alpha}` | Italic α |
| `\Gamma` | Upright Γ |
| `\varGamma` | Italic Γ |
| `\mathit{\Gamma}` | Italic Γ |
| `\mathrm{CO_2}` | Upright CO₂ |
| `\text{max}` | Upright “max” |
| `\mathrm{\alpha}_{max}` | Upright α with subscript max |

A complete axis label can mix text and math:

```text
Concentration (\mathrm{\alpha}) / mol L^{-1}
```

## Where LaTeX applies

### Axis labels

X and Y labels use the full math renderer. Greek letters, font styles,
subscripts, superscripts, fractions, roots, and the other supported commands
work as described above.

### Legend names

Legend display names use plain Unicode substitution, not the full math renderer.
Greek commands and subscripts/superscripts work, but all text stays upright:

| Input | Legend result |
|:--|:--|
| `\alpha` | α |
| `\mathrm{\alpha}` | α |
| `\mathit{\alpha}` | α |
| `\Gamma` | Γ |
| `\mathit{\Gamma}` | Γ |
| `\mathrm{CO_2}` | CO₂ |

Font-style wrappers are stripped for legends. Italic Greek is not available in
legend names. `\varGamma`-style italic uppercase commands are not substituted;
use `\Gamma`, which is upright in legends. Legend names also use the common
Unicode forms: `\epsilon` → ε and `\phi` → φ.

## Limitations

- `\mathrm{...}` and `\text{...}` are handled at the top level of a label.
  Wrapping a command inside another command, such as
  `\frac{\mathrm{\alpha}}{\mathrm{\beta}}`, does not make the nested Greek
  upright.
- `\Alpha`, `\Beta`, `\Epsilon`, and similar uppercase commands are not
  supported by the math renderer. Use the Latin equivalent instead.
- Legend names cannot render italic Greek.
