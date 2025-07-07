# Introduction to `traits_synth`: an API to compute traits from a VSGG SEED

`traits_synth` is a library designed to interpret a VSGG SEED 
(a sequence of 256 integers, each ranging from 0 to 255) 
and transform it into meaningful and measurable traits (such as strength, agility, intelligence, eye color, moral alignment, etc.). 
These traits can be used across a wide range of applications including games, generative art, complex simulations, and digital identity systems.

Each VSGG SEED represents a unique digital identity. `traits_synth` offers a robust and flexible mechanism to map these raw numeric identities into observable and interpretable characteristics in a controlled, deterministic, and coherent way.

### Why `traits_synth`?

In the VSGG protocol, each Vibrant Seed is a trove of potential data. With `traits_synth`, you can:

*   **Precisely define** which positions (indices) of the SEED contribute to each trait.
*   **Aggregate values** from multiple indices, both directly and in inverted form.
*   **Apply different scaling modes and transformations** to map aggregated SEED values to the desired trait range (numerical or categorical).
*   **Establish correlations** — direct or inverse — between SEED values and the resulting traits.
*   **Configure complex behaviors** through custom scaling curves or mathematical expressions.

## Trait Definition in JSON Format

Trait generation from a SEED is configured via a JSON structure. Each top-level key in this JSON represents a trait name, and its value is an object specifying synthesis parameters.

Basic configuration example for two numeric traits:

```json
{
  "strength": {
    "output_min": 1,
    "output_max": 100,
    "direct_indices": [1, 5, 9],
    "scaling_mode": "linear"
  },
  "wisdom": {
    "output_min": 1,
    "output_max": 100,
    "direct_indices": [10, 14, 18],
    "scaling_mode": "linear"
  }
}
```

## Trait Configuration Parameters

Parameters available to configure each trait:

*   `output_min` (int):
    *   If `output_labels` is not provided or is empty, this is the minimum numeric value the trait can assume.
    *   If `output_labels` is provided and non-empty, this parameter is **ignored** for determining the scaling range of label indices (which will correspond to the indices of the `output_labels` list, from 0 to the index of the last label). However, its presence is required by the data structure, even if not actively used in this scenario for scaling.

*   `output_max` (int):
    *   If `output_labels` is not provided or is empty, this is the maximum numeric value the trait can assume.
    *   If `output_labels` is provided and non-empty, this parameter is **ignored** for determining the scaling range of label indices. Like `output_min`, it is structurally required but not used for scaling in the presence of `output_labels`.

*   `output_labels` (Optional\[List\[str]]):
    *   An optional list of strings. If provided and non-empty, the resulting trait will be one of the strings in this list.
    *   In this case, the aggregated SEED value is scaled to produce a valid index for this list (from 0 to the index of the last label).
    *   If `None` or an empty list, the trait will be numeric and determined by `output_min` and `output_max`.
    *   Example: `"output_labels": ["Common", "Rare", "Epic", "Legendary"]`

*   `direct_indices` (Optional\[Union\[int, List\[int]]]):
    *   A single index or a list of indices (from 0 to 255) in the SEED sequence whose values are read as they are.
    *   If multiple indices are provided, their values are averaged before scaling.

*   `inverted_indices` (Optional\[Union\[int, List\[int]]]):
    *   A single index or a list of indices in the SEED sequence whose values are inverted (calculated as `255 - original_value`) before being included in the average.
    *   Useful for traits that need to be inversely correlated with others or specific SEED values.

*   `pivot` (int, default: 0):
    *   An input value (between 0 and 255) that acts as a reference point for some scaling modes (mainly `linear`).
    *   If the output range `[output_min, output_max]` (for numeric traits) includes zero, the `pivot` input value maps to `0` in the output.
    *   Otherwise, `pivot` defines the start of the input range that is mapped to the entire output range.

*   `scaling_mode` (str, default: "linear"):
    *   Specifies the type of transformation (scaling curve) to apply to the average aggregated SEED value.
    *   Supported values: `"linear"`, `"log"`, `"sigmoid"`, `"exponential"`, `"quadratic"`, `"sqrt"`, `"cubic"`, `"cbrt"`, `"reverse"`, `"quantile"`, `"fx"`.

*   `control_points` (Optional\[List\[Dict]], default: []):
    *   Required and used only if `scaling_mode` is `"quantile"`.
    *   A list of dictionaries, each representing a control point for the scaling curve. Each point is defined by `{"quantile": float, "value": float}`.
    *   See the "Advanced Scaling: `quantile`" section for details on ControlPoint format and behavior.

*   `fx_expr` (str, default: ""):
    *   Required and used only if `scaling_mode` is `"fx"`.
    *   A string representing a Python mathematical expression. The expression can use the variable `x`, which represents the average aggregated value from the SEED indices (a float between 0.0 and 255.0), and the `math` module.
    *   The result of the expression is then clamped to the `output_min`/`output_max` range (for numeric outputs) or used to determine the index if `output_labels` is present.
    *   Example: `"fx_expr": "math.pow(x / 255.0, 2) * 100"` (to map input to a 0-100 quadratic output).

## Direct and Inverted Indices

The ability to specify direct and inverted indices is fundamental for creating meaningful relationships between raw SEED data and traits.

*   `direct_indices`: Values read from these SEED positions contribute positively to the trait's aggregated value.
*   `inverted_indices`: Values read from these positions are first subtracted from 255 (the maximum possible value for a SEED element). This is useful for creating traits that are inversely correlated.

If both `direct_indices` and `inverted_indices` are specified, all values (direct and inverted) are collected, and their average is calculated to obtain the raw input value for the scaling function.

**Inverse correlation example:**

Suppose SEED index 50 represents raw "body mass". We want to derive two traits: "Weight" (directly correlated) and "Agility" (inversely correlated).

```json
{
  "weight": {
    "output_min": 30,     // kg
    "output_max": 150,    // kg
    "direct_indices": [50],
    "scaling_mode": "linear"
  },
  "agility": {
    "output_min": 1,      // Agility points
    "output_max": 20,     // Agility points
    "inverted_indices": [50], // Uses the same index, but inverted
    "scaling_mode": "linear"
  }
}
```
In this configuration, a high value at SEED index 50 will result in a high "Weight" and low "Agility", and vice-versa.

## Scaling Modes

The aggregated value from the SEED indices (a float between 0.0 and 255.0) is then transformed by the specified scaling mode.

### `linear` Scaling
This is the default mode. It linearly maps the input range (also determined by the `pivot`) to the specified output range (`output_min`, `output_max` for numeric outputs, or from 0 to the index of the last label for `output_labels`).

### Predefined Scaling Modes
These modes apply common mathematical transformations. They do not require additional parameters in `control_points` or `fx_expr`, as their control points or curves are automatically generated to fit the desired output range.

*   `log`: Applies a logarithmic curve.
*   `sigmoid`: Applies an S-shaped curve (sigmoid).
*   `exponential`: Applies exponential growth.
*   `quadratic`: Applies a quadratic curve (power of 2).
*   `sqrt`: Applies a square root.
*   `cubic`: Applies a cubic curve (power of 3).
*   `cbrt`: Applies a cubic root.
*   `reverse`: Linear inversion. A high input gives a low output and vice-versa, mapped linearly over the output range.

### Advanced Scaling: `quantile`
This mode allows defining a custom scaling curve point by point.

*   Requires the `control_points` parameter.
*   **ControlPoint Format**: Each point in the `control_points` list is a dictionary with two keys:
    *   `quantile` (float): A number between 0.0 and 1.0 (inclusive). It represents the normalized position of the raw input value (0-255) within its range. For example, a `quantile` of 0.0 corresponds to a raw input of 0, 0.5 to 127.5, and 1.0 to 255.
    *   `value` (float): The desired output value (before final clamping to the trait's actual `output_min`/`output_max`) when the normalized input matches this `quantile`.
*   At least two control points are required to define the curve. The points do not need to be provided in order of `quantile` in the JSON configuration; the API will sort them internally before use.
*   Between the defined control points, the API performs linear interpolation. For input values outside the range of defined quantiles (e.g., an input whose normalized quantile is less than the minimum `quantile` provided), the `value` of the nearest control point (minimum or maximum) is returned.

**Example `quantile`:**

```json
{
  "aura_intensity": {
    "output_min": 0,
    "output_max": 100,
    "direct_indices": [77],
    "scaling_mode": "quantile",
    "control_points": [
      {"quantile": 0.0, "value": 0},    // Input 0   -> Output 0
      {"quantile": 0.25, "value": 5},   // Input ~64 -> Output 5
      {"quantile": 0.75, "value": 80},  // Input ~191-> Output 80
      {"quantile": 1.0, "value": 100}   // Input 255 -> Output 100
    ]
  }
}
```
This configuration creates a curve where the aura intensity grows slowly at first, then more rapidly.

### Advanced Scaling: `fx`
This mode offers maximum flexibility by allowing the transformation to be defined via a Python mathematical expression.

*   Requires the `fx_expr` parameter.
*   In the `fx_expr` expression, you can use:
    *   `x`: A variable representing the average aggregated value from the SEED indices (a float between 0.0 and 255.0).
    *   `math`: The Python `math` module for mathematical functions (e.g., `math.sin(x)`, `math.log(x+1)`).
*   The numerical result of the expression is then used:
    *   If `output_labels` is present, the result is scaled (if necessary) and clamped to become a valid index for the `output_labels` list.
    *   Otherwise, the result is clamped to the `[output_min, output_max]` range of the numeric trait.

**Example `fx`:**
For a "Vibrational Frequency" trait that is desired to grow quadratically with respect to a SEED value (normalized) and mapped to a 0-1000 Hz range.

```json
{
  "vibrational_frequency": {
    "output_min": 0,
    "output_max": 1000,
    "direct_indices": [200],
    "scaling_mode": "fx",
    "fx_expr": "math.pow(x / 255.0, 2) * 1000"
  }
}
```
Here, `x / 255.0` normalizes the input to a [0,1] range, `math.pow(..., 2)` squares it, and `* 1000` scales it to the desired output range.

## Full Configuration Example

```json
{
  "hit_points": {
    "output_min": 50,
    "output_max": 250,
    "direct_indices": [10, 11, 12],
    "inverted_indices": [150],
    "pivot": 100,
    "scaling_mode": "linear"
  },
  "elemental_affinity": {
    "output_labels": ["Fire", "Water", "Earth", "Air", "Void"],
    "direct_indices": [20, 21],
    "scaling_mode": "linear"
    // output_min and output_max are formally required by the data structure
    // but ignored for scaling when output_labels is used.
    // Defaults 0 and 255 are used if not specified,
    // or the provided values if present.
    // For clarity, they can be omitted if using defaults,
    // or specified (e.g., 0, 4) even if not used for scaling.
    // The API will internally use indices from 0 to the last label's index for scaling.
    // "output_min": 0, // Ignored for scaling, but structurally present
    // "output_max": 4  // Ignored for scaling, but structurally present
  },
  "luck_factor": {
    "output_min": -10,
    "output_max": 10,
    "direct_indices": [77],
    "scaling_mode": "quantile",
    "control_points": [
      {"quantile": 0.0, "value": -5},
      {"quantile": 0.4, "value": 0},
      {"quantile": 0.6, "value": 0},
      {"quantile": 1.0, "value": 5}
    ]
  },
  "mana_regen_rate": {
    "output_min": 0.5,
    "output_max": 10.0,
    "direct_indices": [30, 31],
    "scaling_mode": "fx",
    "fx_expr": "0.5 + (x / 255.0) * 9.5"
  }
}
```

## Use Cases

Applications for `traits_synth` are manifold:

*   **Generative Game Avatars and Characters**: Create unique stats, abilities, and appearances for characters based on a VSGG SEED.
*   **NFT Metadata on Blockchain**: Generate deterministic and verifiable metadata for NFTs, where traits are derived directly from the SEED either on-chain or off-chain.
*   **Generative Art**: Influence visual or behavioral parameters in digital artworks.
*   **Procedural World Building**: Define characteristics of biomes, creatures, or items in procedurally generated worlds.
*   **AI Model Feature Input**: Provide structured and meaningful inputs to artificial intelligence models, mapping raw numerical values to symbolic or categorical traits.
*   **Digital Identity Systems**: Enrich SEED-based digital identities with a derived set of characteristics.

## Scaling Curve Visualization

The following images show how the different predefined scaling modes transform an input value (derived from the SEED, ranging from 0 to 255) into an output value for a trait. Each graph illustrates all standard scaling modes for a specific combination of `output_min`, `output_max`, and `pivot`. This allows visualizing the impact of these parameters on the shape of the transformation curve, helping to choose the most suitable configuration to achieve the desired behavior for each trait.

The `draw` function calls that generated these graphs are:
*   `draw(output_min=-10, output_max=10, pivot=127)`
*   `draw(output_min=-10, output_max=10, pivot=50)`
*   `draw(output_min=0, output_max=10, pivot=0)`
*   `draw(output_min=0, output_max=100, pivot=0)`
*   `draw(output_min=0, output_max=255, pivot=0)`

*(Charts will be embedded here)*

---