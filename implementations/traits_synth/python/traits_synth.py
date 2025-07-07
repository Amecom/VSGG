# -*- coding: utf-8 -*-
# cdn.vibrantseedsgodsgarden.com
# Created by Amedeo Celletti [amecom@gmail.com] on 09/06/2025
#
import copy
import math
import re

from typing import List, Union, Optional, Dict, Any
from dataclasses import dataclass, field

SEQ_VALUE_MAX = 255

SUPPORTED_SCALING_MODE = [
    "linear",
    "quantile",
    "log",
    "sigmoid",
    "exponential",
    "quadratic",
    "sqrt",
    "cubic",
    "cbrt",
    "reverse",
    "fx"
]


@dataclass
class ControlPoint:
    quantile: float
    value: float


@dataclass
class TraitSynthParams:
    """Parameters for synthesizing a trait value from a sequence.

    Attributes:
        output_labels: Optional list of strings. If provided and not empty, the synthesized
                       trait will be one of these string labels.
                       If defined, the output range is determined by the length of this list
                        and the output_min and output_max parameters are ignored.
        output_min: The minimum value of the output range.
        output_max: The maximum value of the output range.
        direct_indices: An index or list of indices in the sequence whose values
                        are taken as they are. Optional; if provided as a list,
                        it cannot be empty.
        inverted_indices: An index or list of indices in the sequence whose values
                       are reversed (MAX_SEQ_VAL - value) before aggregation.
                       Optional; defaults to an empty list if None.
        pivot: The input value (0-MAX_SEQ_VAL) that is considered the reference
                       point for scaling. If the output range [output_min, output_max]
                       includes 0, this `pivot` input value maps to 0 in the output.
                       Otherwise, `pivot` acts as the start of the input
                       range for scaling against the full output range.
        scaling_mode: The type of scaling to apply. Defaults to "linear".
                      Future types might include "logarithmic", "sigmoid", etc.
        control_points: A dictionary of additional parameters for the chosen scaling_mode=quantile.
                        For example, control points for splines, or quantiles.
                        Optional and its structure depends on the scaling_mode.
        fx_expr: A string representing a mathematical expression to apply to the input value.
    """
    output_labels: Optional[List[str]] = None
    output_min: int = 0
    output_max: int = 255
    # direct_indices è ora opzionale. Se fornito come lista, non può essere vuoto.
    direct_indices: Optional[Union[int, List[int]]] = None
    # Default a lista vuota per reverse_index
    inverted_indices: Optional[Union[int, List[int]]] = None
    pivot: int = 0
    scaling_mode: str = "linear"
    control_points: Optional[List[ControlPoint]] = field(default_factory=list)
    fx_expr: str = ""


def check_valid_sequence(sequence: List[int]):
    """Validates if the sequence is a list of 256 integers,
    with each value between 0 and MAX_SEQ_VAL (inclusive).

    Args:
        sequence: The list of integers to validate.

    Raises:
        csterror.InvalidTokenSequence: If the sequence is invalid (not a list, wrong length,
                    or contains invalid values).
    """
    if not isinstance(sequence, list) or len(sequence) != 256:
        raise Exception("Sequence must be a list of 256 integers.")

    for i, val in enumerate(sequence):
        if not isinstance(val, int) or not (0 <= val <= 255):
            raise Exception(
                f"Sequence value at index {i} ({val}) is invalid. "
                f"Values must be integers between 0 and 255."
            )


def traits_from_sequence(
    sequence: List[int],
    traits_config: Dict[str, Dict[str, Any]]
) -> Dict[str, Union[int, str]]:
    """Calculates multiple trait values from a numeric sequence
    using a JSON-style configuration.

    Args:
        sequence: A list of 256 integers, each in the range [0, 255].
            This sequence typically represents a seed or input data from which trait values are derived.
        traits_config:
            A dictionary where each key is a trait label (string) and each value is a dictionary of parameters for that trait. Each parameter dictionary must include at least:
                - "output_min" (int): Minimum output value for the trait.
                - "output_max" (int): Maximum output value for the trait.
                - "scaling_mode" (str): The scaling mode to use ("linear", "quantile", "log", etc.).
                - "direct_indices" (optional, int or list of int): Indices in the sequence to use directly.
                - "inverted_indices" (optional, int or list of int): Indices in the sequence to use in inverted form.
                - "pivot" (optional, int): Reference input value for scaling.
                - "control_points" (optional, list of dict): For "quantile" scaling, a list of dicts with "quantile" (float, 0.0-1.0) and "value" (float/int).
                - "fx_expr" (optional, str): For "fx" scaling, a mathematical expression as a string.

    Returns:
        A dictionary mapping each trait label (string) to its calculated integer value.

    Raises:
        ValueError: If the input sequence or any trait configuration is invalid, or if required fields are missing.
    """
    check_valid_sequence(sequence)
    results: Dict[str, int] = {}

    for label, params_data in traits_config.items():
        try:
            params = trait_synth_params_from_json(params_data)
            results[label] = trait_from_sequence(sequence, params)
        except TypeError as e:
            raise ValueError(f"Error creating trait '{label}': {e}.") from e

    return results


def trait_from_sequence(sequence: List[int], params: TraitSynthParams) -> Union[int, str]:
    """Calculates a trait value from a numeric sequence
    (seed) based on specified parameters.

    The sequence is a list of 256 integers,
    with values expected to be between 0 and MAX_SEQ_VAL.
    The parameters define how to interpret the sequence and scale the result.

    Args:
        sequence: List of 256 integers (seed values).
                  Common interpretation is that values are 0-255.
                  NOTA: This function does not validate the sequence!

        params: TraitSynthParams instance containing synthesis parameters.

    Returns:
        The calculated integer trait value.

    Raises:
        ValueError: If sequence or parameters are invalid, indices are out of range,
                    or if no valid indices are provided to calculate the raw value.
        NotImplementedError: If a `scaling_mode` other than "linear" is specified.
    """
    validate_trait_synth_params(params)

    output_labels = params.output_labels
    scaling_mode = params.scaling_mode
    control_points = params.control_points
    pivot = params.pivot

    # True se la lista è fornita e non vuota
    use_labels = bool(output_labels)

    if use_labels:
        # Le funzioni di scaling mapperanno average_float a un indice relativo
        # per la sottolista di etichette definita da params.output_min e params.output_max.
        # Il range di questi indici relativi è [0, (params.output_max - params.output_min)].
        output_min = 0
        output_max = len(output_labels) - 1
    else:
        output_min = params.output_min
        output_max = params.output_max

    direct_indices = _transform_index(params.direct_indices)
    inverted_indices = _transform_index(params.inverted_indices)

    aggregated_values = [
        sequence[idx] for idx in direct_indices
    ] + [
        SEQ_VALUE_MAX - sequence[idx] for idx in inverted_indices
    ]

    count = len(aggregated_values)

    if count == 0:
        raise ValueError(
            "No values to average from 'direct_indices' or 'inverted_indices'. "
            "Ensure at least one valid index is provided."
        )

    average_float = sum(aggregated_values) / count

    if scaling_mode == "linear":
        result = _calculate_linearly_scaled_value(
            value=average_float,
            pivot=pivot,
            output_min=output_min,
            output_max=output_max
        )

    elif scaling_mode == "quantile":
        # La funzione _calculate_custom_scaled_value solleverà un ValueError
        # se i control_points non hanno almeno due elementi, il che è un fallback.
        # Se control_points è None, default_factory=list lo imposta a [].
        result = _calculate_quantile_scaled_value(
            value=average_float,
            control_points=control_points,
            output_min=output_min,
            output_max=output_max
        )

    elif scaling_mode == "fx":
        result = _calculate_fx_scaled_value(
            value=average_float,
            fx_expr=params.fx_expr,
            output_min=output_min,
            output_max=output_max
        )

    else:
        control_points = _generate_control_points(
            mode=scaling_mode,
            output_min=output_min,
            output_max=output_max
        )
        result = _calculate_quantile_scaled_value(
            value=average_float,
            control_points=control_points,
            output_min=output_min,
            output_max=output_max
        )

    return output_labels[result] if use_labels else result


def trait_synth_params_from_json(params_data: Dict[str, Any]) -> TraitSynthParams:
    """
    Converts a JSON-style dictionary to a TraitSynthParams object.
    Handles conversion of control_points to ControlPoint objects if scaling_mode is 'quantile'.

    Args:
        params_data: Dictionary with trait synthesis parameters (from JSON).

    Returns:
        TraitSynthParams: The corresponding object.
    """
    params_data_copy = copy.deepcopy(params_data)
    if (
        "control_points" in params_data_copy
        and isinstance(params_data_copy["control_points"], list)
        and params_data_copy.get("scaling_mode") == "quantile"
    ):
        params_data_copy["control_points"] = [
            ControlPoint(**cp)
            for cp in params_data_copy["control_points"]
        ]
    return TraitSynthParams(**params_data_copy)


def validate_trait_synth_params(params: TraitSynthParams):
    """Validates the TraitSynthParams dataclass instance.

    Args:
        params: The TraitSynthParams instance to validate.

    Raises:
        ValueError: If any parameter is invalid.
    """
    if not isinstance(params.output_min, int):
        raise ValueError("Parameter 'output_min' must be an integer.")

    if not isinstance(params.output_max, int):
        raise ValueError("Parameter 'output_max' must be an integer.")

    if not isinstance(params.pivot, int):
        raise ValueError("Parameter 'pivot' must be an integer.")

    _validate_optional_index_param(params.direct_indices, "direct_indices")
    _validate_optional_index_param(params.inverted_indices, "inverted_indices")

    if not (0 <= params.pivot <= SEQ_VALUE_MAX):
        raise ValueError(
            f"Parameter 'pivot' ({params.pivot}) "
            f"must be between 0 and {SEQ_VALUE_MAX}."
        )

    # Validazione di output_labels
    # Può essere una lista vuota o popolata
    if params.output_labels is not None:
        if not isinstance(params.output_labels, list):
            raise ValueError("Parameter 'output_labels' must be a list of strings or None.")
        if params.output_labels:
            # Se la lista è fornita e non è vuota
            if not all(isinstance(label, str) for label in params.output_labels):
                raise ValueError("All elements in 'output_labels' must be strings.")
            # Se output_labels è fornito, output_min e output_max originali sono ignorati
            # per la determinazione del range di scaling, quindi non applichiamo
            # il check output_min <= output_max a questi valori in questo scenario.
            # Tuttavia, potrebbero esserci altre validazioni specifiche per output_min/max
            # se dovessero rappresentare indici per output_labels, ma la logica attuale
            # in trait_from_sequence usa 0 e len(labels)-1.
            # Per ora, ci atteniamo alla docstring che dice che sono ignorati.
        else:
            # output_labels è una lista vuota, trattala come se non fosse fornita per il range
            if params.output_min > params.output_max:
                raise ValueError(
                    f"When 'output_labels' is empty or not used, 'output_min' ({params.output_min}) "
                    f"cannot be greater than 'output_max' ({params.output_max})."
                )
    else:
        # output_labels è None
        if params.output_min > params.output_max:
            raise ValueError(
                f"When 'output_labels' is not used, 'output_min' ({params.output_min}) "
                f"cannot be greater than 'output_max' ({params.output_max})."
            )

    if not isinstance(params.scaling_mode, str):
        raise ValueError("Parameter 'scaling_mode' must be a string.")

    if params.scaling_mode not in SUPPORTED_SCALING_MODE:
        raise ValueError(
            f"Unsupported 'scaling_mode': {params.scaling_mode}. "
            f"Supported types are: {SUPPORTED_SCALING_MODE}"
        )

    # Validazione di control_points
    if params.scaling_mode == "quantile":
        if not isinstance(params.control_points, list):
            raise ValueError(
                "For 'quantile' scaling_mode, 'control_points' must be a list."
            )
        if len(params.control_points) < 2:
            raise ValueError(
                "For 'quantile' scaling_mode, 'control_points' must contain at least two points."
            )

        for i, point in enumerate(params.control_points):
            # Gestisce il caso in cui arrivino da JSON non ancora convertiti
            if isinstance(point, dict):
                quantile = point.get("quantile")
                value = point.get("value")
            elif isinstance(point, ControlPoint):
                quantile = point.quantile
                value = point.value
            else:
                raise ValueError(
                    f"Each item in 'control_points' must be a dict or ControlPoint. Found {type(point)} at index {i}."
                )

            if not isinstance(quantile, (float, int)):
                raise ValueError(
                    f"'quantile' in control_points must be a float or int. Found {type(quantile)} at index {i}."
                )
            if not (0.0 <= float(quantile) <= 1.0):
                raise ValueError(
                    f"'quantile' ({quantile}) in control_points must be between 0.0 and 1.0. Error at index {i}."
                )
            if not isinstance(value, (float, int)):
                raise ValueError(
                    f"'value' in control_points must be a float or int. Found {type(value)} at index {i}."
                )

    # elif params.control_points is not None and params.control_points != []:
    #     # Se control_points è fornito per scaling_mode diversi da "quantile"
    #     # e non è la lista vuota di default, potrebbe essere un errore di configurazione.
    #     # Tuttavia, _generate_control_points crea control_points per altri mode,
    #     # quindi non solleviamo un errore qui se sono forniti, ma non vengono usati
    #     # direttamente da _calculate_quantile_scaled_value a meno che mode non sia "quantile".
    #     # La dataclass permette una lista, quindi è formalmente valido.
    #     pass

    if params.scaling_mode == "fx":
        if not isinstance(params.fx_expr, str) or not params.fx_expr:
            raise ValueError("For 'fx' scaling_mode, 'fx_expr' must be a non-empty string.")
        if not _is_valid_math_expr(params.fx_expr):
            # Assumendo che _is_valid_math_expr sia definita
            raise ValueError(f"Invalid 'fx_expr': {params.fx_expr}. Check for allowed characters and functions.")


def _calculate_linearly_scaled_value(
        value: float,
        pivot: int,
        output_min: int,
        output_max: int
) -> int:
    """
    Performs linear scaling of an input value to an output range.

    If the output range `[overall_output_min, overall_output_max]` includes 0,
    `input_pivot` is treated as the input value that maps to 0 in the output.
    The scaling then occurs in two segments:
    - Input `[0, input_pivot]` maps to Output `[overall_output_min, 0]`
    - Input `[input_pivot, MAX_SEQ_VAL]` maps to Output `[0, overall_output_max]`

    Otherwise (if 0 is not in the output range), it scales the input range
    `[input_pivot, MAX_SEQ_VAL]` to the output range `[overall_output_min, overall_output_max]`.

    Uses integer arithmetic and rounding for the final result.

    Args:
        value: The floating-point input value to scale (typically an average).
        pivot: The input reference value (0-MAX_SEQ_VAL). Its role depends on
                     whether the output range includes zero.
        output_min: The minimum value of the target output range.
        output_max: The maximum value of the target output range.

    Returns:
        The scaled integer value, rounded.
    """

    use_piecewise_logic = (output_min <= 0 <= output_max)
    # Il valore di output a cui input_pivot mappa nella logica a tratti
    # Use float for precision in intermediate calculations
    output_pivot_val = 0.0

    rounded_input_value = int(value + 0.5)

    if use_piecewise_logic:
        # Mappa esattamente input_pivot a output_pivot_val (0), clampato nell'intervallo generale
        if rounded_input_value == pivot:
            return max(output_min, min(output_max, int(output_pivot_val + 0.5)))
        # Segmento inferiore: input [0, input_pivot) -> output [overall_output_min, output_pivot_val)
        elif rounded_input_value < pivot:
            # Se il pivot è 0, e il valore è < 0 (impossibile per input 0-255) o 0 (coperto sopra)
            # Previene la chiamata a _scale_segment con input_pivot == 0 se rounded_input_value è già 0
            if pivot == 0:
                return output_min
            return _scale_segment(
                value=value,
                in_min=0,
                in_max=pivot,
                out_min=output_min,
                out_max=int(output_pivot_val)
            )

        else:
            # rounded_input_value > input_pivot
            # Segmento superiore: input (input_pivot, MAX_SEQ_VAL] -> output (output_pivot_val, overall_output_max]

            # Se il pivot è MAX_SEQ_VAL e valore > MAX_SEQ_VAL (impossibile) o == MAX_SEQ_VAL (coperto sopra)
            if pivot == SEQ_VALUE_MAX:
                return output_max
            return _scale_segment(
                value=value,
                in_min=pivot,
                in_max=SEQ_VALUE_MAX,
                out_min=int(output_pivot_val),
                out_max=output_max
            )

    else:
        # Logica originale non a tratti: input_pivot è l'inizio dell'intervallo di input.
        # Input [input_pivot, MAX_SEQ_VAL] -> Output [overall_output_min, overall_output_max]
        return _scale_segment(
            value=value,
            # Start of input range for non-piecewise
            in_min=pivot,
            in_max=SEQ_VALUE_MAX,
            out_min=output_min,
            out_max=output_max
        )


def _calculate_quantile_scaled_value(
        value: float,
        control_points: List[ControlPoint],
        output_min: int,
        output_max: int
) -> int:
    """Performs quantile scaling based on a list of control points
    using linear interpolation.

    The control_points list should be sorted by 'quantile'.
    The final result is clamped to [overall_output_min, overall_output_max] and rounded.

    Args:
        value: T The floating-point input value to scale (typically an average).
        control_points: A list of dictionaries, e.g., [{"quantile": 0.0, "value": 0.0}, ...].
                        Must contain at least two points and be sorted by "quantile".
                        'quantile' values are expected to be between 0.0 and 1.0.
                        'value' are the target float values for those quantiles.
        output_min: The minimum value for the final clamped output.
        output_max: The maximum value for the final clamped output.

    Returns:
        The scaled integer value, rounded and clamped.

    Raises:
        ValueError: If control_points has fewer than 2 points.
    """
    if not control_points or len(control_points) < 2:
        raise ValueError("Scaling requires at least two control points.")

    normalized_value = value / SEQ_VALUE_MAX
    # Assicura che normalized_input_q sia strettamente tra 0.0 e 1.0 per l'interpolazione.
    normalized_value = max(0.0, min(1.0, normalized_value))

    # Assicura che i punti di controllo siano ordinati per quantile
    sorted_points = sorted(control_points, key=lambda p: p.quantile)

    # Determina il valore interpolato
    interpolated_value: float

    if normalized_value <= sorted_points[0].quantile:
        # Se l'input è prima del primo punto di controllo (o uguale)
        interpolated_value = sorted_points[0].value

    elif normalized_value >= sorted_points[-1].quantile:
        # Se l'input è dopo l'ultimo punto di controllo (o uguale)
        interpolated_value = sorted_points[-1].value

    else:
        # Altrimenti, interpola tra due punti
        p1 = None
        p2 = None
        for i in range(len(sorted_points) - 1):
            if sorted_points[i].quantile <= normalized_value < \
                    sorted_points[i + 1].quantile:
                p1 = sorted_points[i]
                p2 = sorted_points[i + 1]
                break

        # Questo non dovrebbe accadere se normalized_input_q è tra il primo e l'ultimo quantile
        # e i punti sono ordinati e distinti, e normalized_input_q non è uguale all'ultimo quantile.
        if p1 is None or p2 is None:
            # Fallback o errore se non si trova il segmento, anche se la logica sopra dovrebbe coprire tutti i casi.
            # Per robustezza, se non si trova un segmento (improbabile), si potrebbe usare l'ultimo punto.
            # Tuttavia, questo indica un problema con i dati di input o la logica.
            # Data la struttura, p1 e p2 dovrebbero essere trovati.
            # Se normalized_input_q è esattamente uguale a un sorted_points[i]["quantile"],
            # la condizione sorted_points[i]["quantile"] <= normalized_input_q lo cattura come p1.
            # Fallback di sicurezza
            # interpolated_value = sorted_points[-1]["value"]
            raise RuntimeError("Failed to find control points for interpolation. ")

        else:
            q1 = p1.quantile
            v1 = p1.value
            q2 = p2.quantile
            v2 = p2.value

            # Evita divisione per zero se i punti di input sono identici
            if q1 == q2:
                interpolated_value = v1
            else:
                # Calcola il fattore di interpolazione
                factor = (normalized_value - q1) / (q2 - q1)
                interpolated_value = v1 + factor * (v2 - v1)

    return _clamp_and_round(interpolated_value, output_min, output_max)


def _calculate_fx_scaled_value(
    value: float,
    fx_expr: str,
    output_min: int,
    output_max: int
) -> int:
    """
    Applica una funzione quantile (fx_expr) all'input normalizzato e scala il risultato nell'intervallo di output.

    Args:
        value: Valore di input (tipicamente media degli indici selezionati).
        fx_expr: Stringa con l'espressione matematica, ad esempio "math.sin(x) + x**2".
        output_min: Minimo valore di output.
        output_max: Massimo valore di output.

    Returns:
        Valore intero scalato e arrotondato.
    """
    # Normalizza l'input su [0,1]
    x = max(0.0, min(1.0, value / SEQ_VALUE_MAX))
    # Crea la funzione lambda sicura
    fx = _make_safe_lambda(fx_expr)
    # Calcola il valore della funzione
    y = fx(x)
    # Scala il risultato nell'intervallo di output
    scaled = output_min + (y * (output_max - output_min))
    return _clamp_and_round(scaled, output_min, output_max)


def _is_valid_math_expr(expr):
    # Consente numeri, x, operatori, parentesi, spazi e math.NOME
    pattern = r'^[\d\s\+\-\*\/\%\(\)\.,xmathA-Za-z_]+$'
    if not re.fullmatch(pattern, expr):
        return False
    # Trova tutti i math.NOME usati
    matches = re.findall(r'math\.([A-Za-z_][A-Za-z0-9_]*)', expr)
    for name in matches:
        if not hasattr(math, name):
            return False
    # Trova altri identificatori (non math.NOME e non x)
    tokens = re.findall(r'\b([A-Za-z_][A-Za-z0-9_]*)\b', expr)
    for token in tokens:
        if token not in matches and token != "x" and token != "math":
            return False
    return True


def _make_safe_lambda(expr):
    # La validazione _is_valid_math_expr dovrebbe
    # essere chiamata prima di questa funzione
    safe_dict = {"math": math}
    return eval(f"lambda x: {expr}", {"__builtins__": {}}, safe_dict)


def _validate_optional_index_param(
    index_value: Optional[Union[int, List[int]]],
    param_name: str
):
    """Validates an optional index parameter (int, List[int], or None).
    If it's a list, ensures it's not empty and contains integers.
    Also validates that all provided indices are within the range 0-255.

    Args:
        index_value: The index value to validate.
        param_name: The name of the parameter (e.g., "direct_indices")
            for error messages.

    Raises:
        ValueError: If the index value is invalid.
    """
    # None è un valore valido, implica nessun indice da questo parametro.
    if index_value is None:
        return

    indices_to_check: List[int]

    if isinstance(index_value, int):
        indices_to_check = [index_value]
    elif isinstance(index_value, list):
        # Controlla se la lista è vuota
        if not index_value:
            raise ValueError(
                f"Parameter '{param_name}' was provided as an empty list. "
                "If provided, it must not be empty."
            )
        if not all(isinstance(idx, int) for idx in index_value):
            raise ValueError(
                f"All elements in '{param_name}' list must be integers."
            )
        indices_to_check = index_value
    # Questo caso gestisce tipi non corretti
    # non intercettati da Optional[Union[int, List[int]]]
    else:
        raise ValueError(
            f"Parameter '{param_name}' must be an integer, a list of integers, or None."
        )

    # Ora, valida i limiti per tutti gli indici raccolti
    _validate_indices_bounds(indices_to_check)


def _validate_indices_bounds(indices_list: List[int]):
    """
    Checks if all indices in the list are within the valid range (0-255).

    Args:
        indices_list: A list of integer indices.

    Raises:
        ValueError: If any index is out of range or if an element is not an int.
        TypeError: If `indices_list` is not a list (should not happen if called correctly).
    """
    # Questa condizione non dovrebbe verificarsi se chiamata correttamente
    # da _validate_optional_index_param o transform_index
    if not isinstance(indices_list, list):
        # Questo errore è più per lo sviluppo interno, non dovrebbe essere raggiunto dall'utente
        raise TypeError("_validate_indices_bounds expects a list of integers.")

    for idx in indices_list:
        if not isinstance(idx, int):
            raise ValueError(
                f"Index '{idx}' in the list is not an integer. All indices must be integers."
            )
        # Assumendo che la lunghezza della sequenza sia sempre 256
        if not (0 <= idx < 256):
            # Sequence length is 256, so valid indices are 0-255
            raise ValueError(f"Index {idx} is out of range (0-255).")


def _transform_index(index_param: Union[int, List[int], None]) -> List[int]:
    """Transforms an index parameter (int, List[int], or None) into a list of integers.
    Returns an empty list if the input is None.

    Args:
        index_param: The index parameter to transform.

    Returns:
        A list of integers.

    Raises:
        ValueError: If index_param is not an int, list of ints, or None.
    """
    if isinstance(index_param, int):
        return [index_param]
    elif isinstance(index_param, list):
        return index_param
    elif index_param is None:
        return []
    else:
        # Questo errore indica un tipo non valido passato al parametro
        raise ValueError("Index must be an integer, a list of integers, or None.")


def _clamp_and_round(value: float, min_val: float, max_val: float) -> int:
    """Clamps a float value to the range [min_val, max_val]
    and rounds to the nearest integer.

    Args:
        value: The float to process.
        min_val: Minimum allowed value.
        max_val: Maximum allowed value.

    Returns:
        An integer result after clamping and rounding.
    """
    return int(math.floor(max(min_val, min(max_val, value)) + 0.5))


def _optimal_num_points(output_min: float, output_max: float) -> int:
    """Calcola un numero ottimale di punti di controllo in base all'intervallo di output.
    Usa una scala logaritmica per evitare troppi punti su intervalli grandi.
    """
    span = abs(output_max - output_min)
    # Minimo 4 punti, massimo 32 punti
    return max(4, min(32, int(4 + math.log2(span + 1) * 3)))


def _generate_control_points(
    mode: str,
    output_min: float,
    output_max: float
) -> List[ControlPoint]:
    """Genera una lista di control points per vari scaling_mode.

    Args:
        mode: Il tipo di scaling da applicare.
        output_min: valore minimo dell'output
        output_max: valore massimo dell'output

    Returns:
        Lista di dict con chiavi 'quantile' e 'value'
    """
    num_points = _optimal_num_points(output_min, output_max)

    control_points = []
    for i in range(num_points):
        quantile = i / (num_points - 1)

        if mode == "log":
            # logaritmo simulato: log(1 + 9 * x) normalizzato su [0,1]
            y = math.log1p(9 * quantile) / math.log1p(9)

        elif mode == "sigmoid":
            # sigmoid centrata in 0.5, range [0,1]
            y = 1 / (1 + math.exp(-12 * (quantile - 0.5)))

        elif mode == "exponential":
            # Esponenziale normalizzata su [0,1]: y = (exp(k * x) - 1) / (exp(k) - 1)
            k = 4  # Puoi regolare k per la "curvatura"
            y = (math.exp(k * quantile) - 1) / (math.exp(k) - 1)

        elif mode == "quadratic":
            y = quantile ** 2

        elif mode == "sqrt":
            y = math.sqrt(quantile)

        elif mode == "cubic":
            y = quantile ** 3

        elif mode == "cbrt":
            y = math.copysign(abs(quantile) ** (1 / 3), quantile)

        elif mode == "reverse":
            y = 1 - quantile
        else:
            raise ValueError("scaling_mode not supported.")

        value = output_min + y * (output_max - output_min)
        control_points.append(ControlPoint(quantile=quantile, value=value))

    return control_points


def _scale_segment(
        value: float,
        in_min: int,
        in_max: int,
        out_min: int,
        out_max: int
) -> int:
    """
    Scales a value from one segment [s_in_min, s_in_max] to another [s_out_min, s_out_max].
    Handles edge cases and uses integer arithmetic with rounding.
    """
    # Arrotonda il valore di input per il segmento
    # math.floor per coerenza con l'arrotondamento verso lo zero implicito nella divisione intera
    # ma aggiungendo 0.5 per arrotondare al più vicino.
    val_int = int(value + 0.5)

    # Gestisce i casi limite in cui il valore è ai bordi o fuori dal segmento di input
    if val_int <= in_min:
        return out_min
    if val_int >= in_max:
        return out_max

    # A questo punto: s_in_min < val_int < s_in_max.
    # Questo implica che s_in_min < s_in_max, quindi input_span_seg > 0.
    input_span_seg = in_max - in_min
    output_span_seg = out_max - out_min
    # Questo è > 0
    value_offset_seg = val_int - in_min

    # Esegue la scalatura con aritmetica intera e arrotondamento
    # Add half of the divisor for rounding before integer division
    scaled_increment_numerator = value_offset_seg * output_span_seg
    # Aggiunge metà del divisore (input_span_seg) per l'arrotondamento prima della divisione intera
    scaled_val_intermediate = out_min + (
            (scaled_increment_numerator + input_span_seg // 2) // input_span_seg
    )

    # Clamp finale per sicurezza, anche se la logica dovrebbe già mantenerlo nei limiti
    return _clamp_and_round(scaled_val_intermediate, out_min, out_max)
