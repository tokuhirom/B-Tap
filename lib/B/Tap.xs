#ifdef __cplusplus
extern "C" {
#endif

#define PERL_NO_GET_CONTEXT /* we want efficiency */
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#ifdef __cplusplus
} /* extern "C" */
#endif

#define NEED_newSVpvn_flags
#include "ppport.h"

static XOP my_xop_tap;
static XOP my_xop_push_sv;

static OP *XS_B_Tap_pp_push_sv(pTHX) {
    dXSARGS;

    SV* const sv = cSVOP_sv;
    /* I know what this temporary variable is ugly. Patches welcome. */
    SV * tmp = get_sv("B::Tap::_TMP", GV_ADD);
    sv_setsv(tmp, sv);

    RETURN;
}

static OP *XS_B_Tap_pp_tap(pTHX) {
    dXSARGS;
    int i;
    SV *tmp;
    AV *ret = newAV();

    av_push(ret, newSViv(GIMME_V));
    if (GIMME_V == G_SCALAR) {
        SvREFCNT_inc(ST(0));
        av_push(ret, ST(0));
    } else if (GIMME_V == G_VOID) {
        /* do nothing */
    } else {
        AV * av = newAV();
        for (i=0; i<items; i++) {
            SvREFCNT_inc(ST(i));
            av_push(av, ST(i));
        }
        av_push(ret, newRV_noinc((SV*)av));
    }

    /* I know what this temporary variable is ugly. Patches welcome. */
    tmp = get_sv("B::Tap::_TMP", GV_ADD);
    if (SvROK(tmp) && SvTYPE(SvRV(tmp)) == SVt_PVAV) {
        av_push((AV*)SvRV(tmp), newRV_noinc((SV*)ret));
    } else {
        sv_dump(tmp);
        croak("ArrayRef is expected, but it's not ArrayRef.");
    }

    RETURN;
}

#define RECURSE(next) rewrite_op(aTHX_ (OP*)next, orig, replacement)
#define REPLACE(type, meth) \
    if (((type)root)->meth == orig) { \
        ((type)root)->meth = replacement; \
    } else {\
        RECURSE(((type)root)->meth); \
    }

static void rewrite_op(pTHX_ OP* root, OP* orig, OP* replacement) {
    switch (OP_CLASS(root)) {
    case OA_UNOP:
        REPLACE(UNOP*, op_first);
        break;
    case OA_BINOP:
        REPLACE(BINOP*, op_first);
        REPLACE(BINOP*, op_last);
        break;
    case OA_LOGOP:
        REPLACE(LOGOP*, op_first);
        REPLACE(LOGOP*, op_other);
        break;
    case OA_LISTOP:
        REPLACE(LOGOP*, op_first);
        break;
    }

    if (root->op_sibling) {
        if (root->op_sibling == orig) {
            root->op_sibling = replacement;
        } else {
            rewrite_op(aTHX_ (OP*)root->op_sibling, orig, replacement);
        }
    }
}

#undef RECURSE

MODULE = B::Tap    PACKAGE = B::Tap

PROTOTYPES: DISABLE

BOOT:
    /* Register custom ops */
    XopENTRY_set(&my_xop_tap, xop_name, "b_tap_tap");
    XopENTRY_set(&my_xop_tap, xop_desc, "b_tap_tap");
    XopENTRY_set(&my_xop_tap, xop_class, OA_BINOP);
    Perl_custom_op_register(aTHX_ XS_B_Tap_pp_tap, &my_xop_tap);

    XopENTRY_set(&my_xop_push_sv, xop_name, "b_tap_push_sv");
    XopENTRY_set(&my_xop_push_sv, xop_desc, "b_Tap_push_sv");
    XopENTRY_set(&my_xop_push_sv, xop_class, OA_SVOP);
    Perl_custom_op_register(aTHX_ XS_B_Tap_pp_push_sv, &my_xop_push_sv);

    /* Register constats */
    HV* stash = gv_stashpvn("B::Tap", strlen("B::Tap"), TRUE);
    newCONSTSUB(stash, "G_SCALAR", newSViv(G_SCALAR));
    newCONSTSUB(stash, "G_ARRAY",  newSViv(G_ARRAY));
    newCONSTSUB(stash, "G_VOID",   newSViv(G_VOID));

void
_tap(opp, root_opp, buf)
    void* opp;
    void* root_opp;
    SV * buf;
CODE:
{
    /* Rewrite op tree. */
    OP * orig_op = (OP*)opp;
    OP * next_op = orig_op->op_next;
    OP * sibling_op = orig_op->op_sibling;

    SVOP * push_sv = (SVOP*)newSVOP(OP_CUSTOM, 0, buf);
    push_sv->op_ppaddr = XS_B_Tap_pp_push_sv;
    push_sv->op_flags  = OPf_WANT_LIST;
    push_sv->op_sv = buf;
    SvREFCNT_inc(buf);

    BINOP * b_tap = (BINOP*)newBINOP(OP_CUSTOM, 0, orig_op, (OP*)push_sv);
    b_tap->op_ppaddr   = XS_B_Tap_pp_tap;
    b_tap->op_flags    = orig_op->op_flags & OPf_WANT;
    b_tap->op_first    = orig_op;
    b_tap->op_last     = (OP*)push_sv;
    b_tap->op_sibling  = sibling_op;

    orig_op->op_next   = (OP*)push_sv;
    push_sv->op_next   = (OP*)b_tap;
    b_tap->op_next     = next_op;

    rewrite_op(aTHX_ (OP*)root_opp, (OP*)orig_op, (OP*)b_tap);
}

