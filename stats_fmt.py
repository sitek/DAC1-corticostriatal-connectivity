"""
Formatting helpers for consistent APA-style statistical reporting.

Ported from SoundBrainLab/fMRI_auditory-category-learning/stats_fmt.py
with adaptations for hcp7t_mrtrix3_TianS2: export_anova takes statsmodels
AnovaRM *or* pingouin rm_anova; export_posthoc takes parametric *or*
Wilcoxon pg.pairwise_tests output.

    print(fmt_F(2, 22, 4.123))              # "F(2, 22) = 4.12"
    print(fmt_p(0.0003))                    # "p < .001"
    print(stat_str('t', 11, 2.345, 0.038))  # "t(11) = 2.35, p = .038"
    print(stat_str('W', 82.0, 0.03))        # "W = 82.0, p = .030"
"""

import os


def fmt_p(p: float) -> str:
    """Format a p-value to 3 decimal places, APA style (no leading zero).
    Values below .001 reported as 'p < .001'. NaN -> 'n/a' (e.g. pingouin
    leaves p-corr NaN on the main-effect rows of a pairwise_tests table)."""
    if p != p:  # NaN
        return "n/a"
    if p < 0.001:
        return "p < .001"
    return f"p = {p:.3f}".replace("0.", ".")


def fmt_t(df, t):
    """Format a t-statistic with degrees of freedom."""
    return f"t({df}) = {t:.2f}"


def _fmt_df(x):
    """Whole numbers as ints, Greenhouse-Geisser-corrected df as 2 decimals."""
    x = float(x)
    return str(int(x)) if x.is_integer() else f"{x:.2f}"


def fmt_F(df1, df2, F):
    """Format an F-statistic with numerator and denominator degrees of freedom."""
    return f"F({_fmt_df(df1)}, {_fmt_df(df2)}) = {F:.2f}"


def fmt_eta2(x: float) -> str:
    """Partial eta-squared, 2 decimals, APA style (no leading zero)."""
    if x != x:  # NaN
        return ""
    return f"ηp² = {x:.2f}".replace("= 0.", "= .").replace("= -0.", "= -.")


def fmt_r(r: float) -> str:
    """Format a correlation coefficient to 2 decimal places, no leading zero."""
    return f"r = {r:.2f}".replace("r = 0.", "r = .").replace("r = -0.", "r = -.")


def fmt_z(z: float) -> str:
    """Format a z-statistic to 2 decimal places."""
    return f"z = {z:.2f}"


def fmt_W(W: float) -> str:
    """Format a Wilcoxon signed-rank statistic."""
    return f"W = {W:.1f}"


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
    elif stat_type == 'W':
        W_val, p_val = args
        return f"{fmt_W(W_val)}, {fmt_p(p_val)}"
    else:
        raise ValueError(f"Unknown stat_type '{stat_type}'. Use 't', 'F', 'r', 'z', or 'W'.")


def stat_str_fdr(stat_type, *args):
    """
    Like stat_str but replaces the uncorrected p with an FDR-corrected q.
    Last argument is always p_fdr (NaN -> just the statistic, no q).

    Examples
    --------
    stat_str_fdr('t', 11, 2.345, 0.038, 0.045)   # "t(11) = 2.35, q = .045"
    stat_str_fdr('W', 82.0, 0.030, 0.21)         # "W = 82.0, q = .210"
    """
    *stat_args, p_fdr = args
    stat_part = stat_str(stat_type, *stat_args).rsplit(',', 1)[0]
    if p_fdr != p_fdr:  # NaN -> no FDR value to report (e.g. main-effect row)
        return stat_part
    if p_fdr < 0.001:
        q_str = "q < .001"
    else:
        q_str = f"q = {p_fdr:.3f}".replace("0.", ".")
    return f"{stat_part}, {q_str}"


def export_anova(aov, label, out_dir='.', filename=None):
    """
    Convert a repeated-measures ANOVA result to a tidy DataFrame and save as TSV.

    Accepts either:
      - a statsmodels AnovaRM fitted result (has .anova_table); or
      - a pingouin rm_anova DataFrame, fitted with detailed=True and
        effsize='np2' (correction defaults to 'auto', which applies
        Greenhouse-Geisser to factors with >2 levels).

    Output columns: source, F, df_num, df_den, p, p_gg, np2, eps, stat_str
    p_gg / np2 / eps are blank for statsmodels input. When a factor's
    sphericity epsilon < 1, stat_str reports the GG-corrected p and
    GG-corrected (fractional) degrees of freedom.
    """
    from math import isnan

    if hasattr(aov, 'anova_table'):
        t = aov.anova_table.copy()
        t.index.name = 'source'
        t = t.reset_index()
        t.columns = ['source', 'F', 'df_num', 'df_den', 'p']
        t['p_gg'] = float('nan')
        t['np2'] = float('nan')
        t['eps'] = float('nan')
    else:
        d = aov.copy()
        d = d.rename(columns={'Source': 'source', 'p-unc': 'p_unc',
                              'p-GG-corr': 'p_GG_corr'})
        if 'ddof1' not in d.columns and 'DF' in d.columns:
            # 1-way rm_anova: one 'DF' column and a trailing 'Error' row
            err = d[d['source'] == 'Error']
            df_den = float(err['DF'].iloc[0]) if len(err) else float('nan')
            d = d[d['source'] != 'Error'].copy()
            d['df_num'] = d['DF'].astype(float)
            d['df_den'] = df_den
        else:
            d = d.rename(columns={'ddof1': 'df_num', 'ddof2': 'df_den'})
        for c in ('p_GG_corr', 'np2', 'eps'):
            if c not in d.columns:
                d[c] = float('nan')
        t = d[['source', 'F', 'df_num', 'df_den', 'p_unc',
               'p_GG_corr', 'np2', 'eps']].rename(
            columns={'p_unc': 'p', 'p_GG_corr': 'p_gg'})

    def _mk(r):
        eps, p_gg, np2 = float(r['eps']), float(r['p_gg']), float(r['np2'])
        use_gg = not isnan(eps) and eps < 0.999 and not isnan(p_gg)
        df1, df2 = float(r['df_num']), float(r['df_den'])
        if use_gg:
            df1, df2 = df1 * eps, df2 * eps
        s = f"{fmt_F(df1, df2, float(r['F']))}, {fmt_p(p_gg if use_gg else float(r['p']))}"
        if use_gg:
            s += f" (GG ε={eps:.2f})"
        if not isnan(np2):
            s += f", {fmt_eta2(np2)}"
        return s

    blank_nan = lambda fmt: (lambda x: '' if isnan(float(x)) else fmt(float(x)))
    t['stat_str'] = t.apply(_mk, axis=1)
    t['F'] = t['F'].map(lambda x: f'{float(x):.2f}')
    t['p'] = t['p'].map(lambda x: fmt_p(float(x)))
    t['p_gg'] = t['p_gg'].map(blank_nan(fmt_p))
    t['np2'] = t['np2'].map(blank_nan(lambda x: f'{x:.3f}'))
    t['eps'] = t['eps'].map(blank_nan(lambda x: f'{x:.3f}'))
    t = t[['source', 'F', 'df_num', 'df_den', 'p', 'p_gg', 'np2', 'eps', 'stat_str']]

    os.makedirs(out_dir, exist_ok=True)
    fname = filename or f'anova_{label}.tsv'
    t.to_csv(os.path.join(out_dir, fname), sep='\t', index=False)
    return t


def export_posthoc(pg_df, label, out_dir='.', filename=None):
    """
    Convert a pg.pairwise_tests result to a clean DataFrame and save as TSV.

    Handles both the parametric (paired t: 'T' / 'dof' columns) and the
    non-parametric (Wilcoxon signed-rank: 'W-val' / 'W_val') output of
    pg.pairwise_tests, and both pingouin column conventions ('p-unc'/'p-corr'
    and 'p_unc'/'p_corr').
    """
    df = pg_df.rename(columns={'p-unc': 'p_unc', 'p-corr': 'p_corr',
                               'p-adjust': 'p_corr', 'W-val': 'W_val'})

    grouping_cols = [c for c in ['Contrast', 'Cortex_ROI', 'Cortex_Category',
                                 'Caudate_Putamen', 'Rostral_Caudal',
                                 'hemisphere', 'Striatum_ROI', 'A', 'B']
                     if c in df.columns]
    has_fdr = 'p_corr' in df.columns
    nonparam = 'W_val' in df.columns and 'T' not in df.columns

    kind = 'W' if nonparam else 't'
    stat_in, stat_out = ('W_val', 'W') if nonparam else ('T', 't')
    df_cols = [] if nonparam else ['dof']
    stat_fmt = (lambda x: f'{float(x):.1f}') if nonparam else '{:.2f}'.format

    try:
        cols = grouping_cols + [stat_in] + df_cols + ['p_unc'] + \
               (['p_corr'] if has_fdr else [])
        table = df[cols].rename(columns={stat_in: stat_out, 'dof': 'df',
                                         'p_unc': 'p', 'p_corr': 'p_fdr'})
    except KeyError as e:
        raise KeyError(f"export_posthoc: missing column {e}. "
                       f"Available: {list(df.columns)}") from e

    def _args(r):
        return (kind, float(r['W']), r['p']) if nonparam \
            else (kind, int(r['df']), r['t'], r['p'])

    table['stat_str'] = table.apply(lambda r: stat_str(*_args(r)), axis=1)
    table['stat_str_fdr'] = table.apply(
        lambda r: stat_str_fdr(*_args(r), r['p_fdr']), axis=1) if has_fdr else ''

    table[stat_out] = table[stat_out].map(stat_fmt)
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
