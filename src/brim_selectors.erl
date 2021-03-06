%%% Copyright (c) 2012 Per Melin <p@greendale.se>. See file LICENSE.

-module(brim_selectors).

-export([parse/1]).

-define(true, fun(_) -> true end).

parse({selector, S}) ->
    pred(S);
parse(S) when is_list(S) ->
    parse(brim_selector_lex:scan(S)).

pred(Selectors) ->
    pred(lists:reverse(Selectors), ?true).

pred([Selector|T], Pred) ->
    case Selector of
        {id, ID} ->
            pred(T, fun(Tree) ->
                brim_html:has_id(Tree, ID) andalso Pred(Tree)
            end);
        {class, Class} ->
            pred(T, fun(Tree) ->
                brim_html:has_class(Tree, Class) andalso Pred(Tree)
            end);
        {attrib, Attr} ->
            pred(T, fun(Tree) ->
                brim_html:attribute(Tree, Attr) /= error andalso Pred(Tree)
            end);
        {attrib, Attr, Test, Val} ->
            pred(T, fun(Tree) ->
                Pred(Tree) andalso
                    compare_attr(brim_html:attribute(Tree, Attr), Test, Val)
            end);
        {pseudo, empty} ->
            pred(T, fun(Tree) ->
                brim_html:is_empty(Tree) andalso Pred(Tree)
            end);
        {pseudo, 'nth-child', N} ->
            pred(T, is_nth_pred(Pred, fun is_nth/3, fun ziptree:left/1, N));
        {pseudo, 'nth-last-child', N} ->
            pred(T, is_nth_pred(Pred, fun is_nth/3, fun ziptree:right/1, N));
        {pseudo, 'first-child'} ->
            pred(T, is_nth_pred(Pred, fun is_nth/3, fun ziptree:left/1, 1));
        {pseudo, 'last-child'} ->
            pred(T, is_nth_pred(Pred, fun is_nth/3, fun ziptree:right/1, 1));
        {pseudo, 'nth-of-type', N} ->
            pred(T, is_nth_pred(Pred, fun is_nth_of_type/3, fun ziptree:left/1, N));
        {pseudo, 'nth-last-of-type', N} ->
            pred(T, is_nth_pred(Pred, fun is_nth_of_type/3, fun ziptree:right/1, N));
        {pseudo, 'first-of-type'} ->
            pred(T, is_nth_pred(Pred, fun is_nth_of_type/3, fun ziptree:left/1, 1));
        {pseudo, 'last-of-type'} ->
            pred(T, is_nth_pred(Pred, fun is_nth_of_type/3, fun ziptree:right/1, 1));
        {pseudo, 'not', Selectors} ->
            NotPred = pred(Selectors, ?true),
            pred(T, fun(Tree) ->
                Pred(Tree)
                    andalso brim_html:is_type(Tree, "*")
                    andalso not NotPred(Tree)
            end);
        {relation, parent} ->
            RelPred = pred(T, ?true),
            fun(Tree) ->
                Ancestor = ziptree:up(Tree),
                Ancestor /= error andalso RelPred(Ancestor) andalso Pred(Tree)
            end;
        {relation, ancestor} ->
            RelPred = pred(T, ?true),
            fun(Tree) ->
                Pred(Tree) andalso find_relative(Tree, RelPred, fun ziptree:up/1)
            end;
        {relation, sibling} ->
            RelPred = pred(T, ?true),
            fun(Tree) ->
                Pred(Tree) andalso find_relative(Tree, RelPred, fun ziptree:left/1)
            end;
        {element, Type} ->
            pred(T, fun(Tree) ->
                brim_html:is_type(Tree, Type) andalso Pred(Tree)
            end)
    end;
pred([], Pred) ->
    Pred.

compare_attr(error, _, _)       -> false;
compare_attr(A, equals,      B) -> A == B;
compare_attr(A, begins_with, B) -> lists:prefix(B, A);
compare_attr(A, ends_with,   B) -> lists:suffix(B, A);
compare_attr(A, contains,    B) -> string:str(A, B) > 0;
compare_attr(A, includes,    B) -> lists:member(B, string:tokens(A, " ")).

find_relative(Tree, Pred, Step) ->
    case Step(Tree) of
        error    -> false;
        Relative -> Pred(Relative) orelse find_relative(Relative, Pred, Step)
    end.

is_nth_pred(Pred, TestFun, StepFun, N) ->
    fun(Tree) ->
        Pred(Tree) andalso TestFun(Tree, StepFun, N)
    end.

is_nth(Tree, StepFun, N) ->
    is_nth_of_type(Tree, StepFun, "*", N).

is_nth_of_type(Tree, StepFun, N) ->
    is_nth_of_type(Tree, StepFun, brim_html:type(Tree), N).

is_nth_of_type(error, _, _, N) ->
    N =:= 0;
is_nth_of_type(Tree, StepFun, Type, N) when N >= 0 ->
    case brim_html:is_type(Tree, Type) of
        true -> is_nth_of_type(StepFun(Tree), StepFun, Type, N - 1);
        _    -> is_nth_of_type(StepFun(Tree), StepFun, Type, N)
    end;
is_nth_of_type(_, _, _, _) ->
    false.
