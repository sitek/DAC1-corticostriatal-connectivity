import os

"""
Formatting helpers for consistent APA-style statistical reporting.

Ported from SoundBrainLab/fMRI_auditory-category-learning/stats_fmt.py
with minor adaptations for hcp7t_mrtrix3_TianS2 (pingouin column-name
variants, default out_dir).

Usage:
    from stats_fmt import fmt_t, fmt_F, fmt_p, fmt_r, stat_str

    print(fmt_t(11, 2.345))                    # "t(11) = 2.35"
    print(fmt_F(2, 22, 4.123))                 # "F(2, 22) = 4.12"
    print(fmt_p(0.0003))                       # "p < .001"
    print(fmt_r(0.7823))                       # "r = .78"
    print(stat_str('t', 11, 2.345, 0.038))    # "t(11) = 2.35, p = .038"
"""


def fmt_p(p: float) -> str:
    """Format a p-value to 3 decimal places, APA style (no leading zero).
    Values below .001 reported as 'p < .001'."""
    if p < 0.001:
        return "p < .001"
    return f"p = {p:.3f}".replace("0.", ".")


def fmt_t(df, t):
    """Format a t-statistic with degrees of freedom."""
    return f"t({df}) = {t:.2f}"


def fmt_F(df1, df2, F):
    """Format an F-statistic with numerator and denominator degrees of freedom."""
    return f"F({df1}, {df2}) = {F:.2f}"


def fmt_r(r: float) -> str:
    """Format a correlation coefficient to 2 decimal places, no leading zero."""
    return f"r = {r:.2f}".replace("r = 0.", "r = .").replace("r = -0.", "r = -.")


def fmt_z(z: float) -> str:
    """Format a z-statistic to 2 decimal places."""
    return f"z = {z:.2f}"


def stat_str(stat_type: str, *args) -> str:
    """
    Convenience wrapper that returns a full 'stat, p' string.

    Examples
    --------
    stat_str('t', df, t_val, p_val)
    stat_str('F', df1, df2, F_val, p_val)
    stat_str('r', r_val, p_val)
    """
    if stat_type == 't':
        df, t_val, p_val = args
        return f"{fmt_t(df, t_val)}, {fmt_p(p_val)}"
    elif stat_type == 'F':
        df1, df2, F_val, p_val = args
        return f"{fmt_F(df1, df2, F_val)}, {fmt_p(p_val)}"
    elif stat_type == 'r':
        r_val, p_val = args
        return f"{fmt_r(r_val)}, {fmt_p(p_val)}"
    elif stat_type == 'z':
        z_val, p_val = args
        return f"{fmt_z(z_val)}, {fmt_p(p_val)}"
    else:
        raise ValueError(f"Unknown stat_type '{stat_type}'. Use 't', 'F', 'r', or 'z'.")


def stat_str_fdr(stat_type, *args):
    """
    Like stat_str but appends a FDR-corrected p-value.
    Last argument is always p_fdr.

    Examples
    --------
    stat_str_fdr('t', 11, 2.345, 0.038, 0.045)   # "t(11) = 2.35, p = .038, p_FDR = .045"
    stat_str_fdr('F', 2, 22, 4.12, 0.031, 0.048) # "F(2, 22) = 4.12, p = .031, p_FDR = .048"
    """
    *stat_args, p_fdr = args
    stat_part = stat_str(stat_type, *stat_args).rsplit(',', 1)[0]
    if p_fdr < 0.001:
        q_str = "q < .001"
    else:
        q_str = f"q = {p_fdr:.3f}".replace("0.", ".")
    return f"{stat_part}, {q_str}"


def export_anova(aov, label, out_dir='.', filename=None):
    """
    Convert an AnovaRM result to a clean DataFrame and save as TSV.

    Parameters
    ----------
    aov      : AnovaRM fitted result (has .anova_table attribute)
    label    : str, used in filename if filename not provided
    out_dir  : str, directory to save TSV (default '.')
    filename : str, optional override for output filename
    """
    table = aov.anova_table.copy()
    table.index.name = 'source'
    table = table.reset_index()
    table.columns = ['source', 'F', 'df_num', 'df_den', 'p']
    table['stat_str'] = table.apply(
        lambda r: stat_str('F', int(r['df_num']), int(r['df_den']), r['F'], r['p']), axis=1)
    table = table[['source', 'F', 'df_num', 'df_den', 'p', 'stat_str']]
    table['F'] = table['F'].map('{:.2f}'.format)
    table['p'] = table['p'].map(lambda x: fmt_p(float(x)) if x is not None else x)

    os.makedirs(out_dir, exist_ok=True)
    fname = filename or f'anova_{label}.tsv'
    table.to_csv(os.path.join(out_dir, fname), sep='\t', index=False)
    return table


def export_posthoc(pg_df, label, out_dir='.', filename=None):
    """
    Convert a pg.pairwise_tests result to a clean DataFrame and save as TSV.
    Handles both pingouin column conventions: 'p-unc'/'p-corr' and 'p_unc'/'p_corr'.

    Parameters
    ----------
    pg_df    : pd.DataFrame, output of pg.pairwise_tests()
    label    : str, used in filename if filename not provided
    out_dir  : str, directory to save TSV (default '.')
    filename : str, optional override for output filename
    """
    from numpy import nan

    # Normalise column names: pingouin uses hyphens in newer versions,
    # underscores in some older ones.
    df = pg_df.rename(columns={'p-unc': 'p_unc', 'p-corr': 'p_corr',
                                'p-adjust': 'p_corr'})

    grouping_cols = [c for c in ['Contrast', 'Cortex_ROI', 'Cortex_Category',
                                  'Caudate_Putamen', 'Rostral_Caudal',
                                  'hemisphere', 'Striatum_ROI', 'A', 'B']
                     if c in df.columns]

    has_fdr = 'p_corr' in df.columns

    try:
        cols = grouping_cols + ['T', 'dof', 'p_unc'] + (['p_corr'] if has_fdr else [])
        table = df[cols].copy().rename(columns={'T': 't', 'dof': 'df',
                                                 'p_unc': 'p', 'p_corr': 'p_fdr'})
        table['stat_str'] = table.apply(
            lambda r: stat_str('t', int(r['df']), r['t'], r['p']), axis=1)
        if has_fdr:
            table['stat_str_fdr'] = table.apply(
                lambda r: stat_str_fdr('t', int(r['df']), r['t'], r['p'], r['p_fdr']), axis=1)
        else:
            table['stat_str_fdr'] = nan
    except KeyError as e:
        raise KeyError(f"export_posthoc: missing column {e}. "
                       f"Available: {list(df.columns)}") from e

    table['t'] = table['t'].map('{:.2f}'.format)
    table['p'] = table['p'].map(lambda x: fmt_p(float(x)) if x is not None else x)
    if 'p_fdr' in table.columns:
        table['p_fdr'] = table['p_fdr'].map(lambda x: fmt_p(float(x)) if x is not None else x)

    os.makedirs(out_dir, exist_ok=True)
    fname = filename or f'posthoc_{label}.tsv'
    table.to_csv(os.path.join(out_dir, fname), sep='\t', index=False)
    return table


def export_ttests(records, label, out_dir='.', filename=None):
    """
    Convert a list of ttest results to a clean DataFrame and save as TSV.
    Applies FDR correction across all tests.

    Each record should have: label (str), t (float), df (int), p (float).
    """
    from statsmodels.stats.multitest import multipletests
    from pandas import DataFrame
    table = DataFrame(records)
    _, p_fdr = multipletests(table['p'], method='fdr_bh')[:2]
    table['p_fdr'] = p_fdr
    table['stat_str'] = table.apply(
        lambda r: stat_str('t', int(r['df']), r['t'], r['p']), axis=1)
    table['stat_str_fdr'] = table.apply(
        lambda r: stat_str_fdr('t', int(r['df']), r['t'], r['p'], r['p_fdr']), axis=1)

    table['t'] = table['t'].map('{:.2f}'.format)
    table['p'] = table['p'].map(lambda x: fmt_p(float(x)) if x is not None else x)
    table['p_fdr'] = table['p_fdr'].map(lambda x: fmt_p(float(x)) if x is not None else x)

    os.makedirs(out_dir, exist_ok=True)
    fname = filename or f'ttests_{label}.tsv'
    table.to_csv(os.path.join(out_dir, fname), sep='\t', index=False)
    return table


def fmt_pingouin_anova(aov_df, term_col: str = 'Source') -> dict:
    """
    Convert a pingouin ANOVA DataFrame to a dict of formatted strings keyed by term name.
    Each value is ready to paste into manuscript text.
    """
    out = {}
    for _, row in aov_df.iterrows():
        name = row[term_col]
        df1 = int(row.get('ddof1', row.get('DF', '?')))
        df2_key = 'ddof2' if 'ddof2' in row else ('DF2' if 'DF2' in row else None)
        df2 = int(row[df2_key]) if df2_key else '?'
        F = row.get('F', float('nan'))
        p = row.get('p-unc', row.get('p-GG-corr', float('nan')))
        out[name] = stat_str('F', df1, df2, F, p)
    return out
