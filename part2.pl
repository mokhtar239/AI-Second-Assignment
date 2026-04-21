
% FILE LAYOUT
%   Section A  — Grid fact (the map).
%   Section B  — State representation (documented).
%   Section C  — Grid helpers: cell access, bounds, passability.
%   Section D  — Moves: neighbor generation.
%   Section E  — Survivor utilities + Manhattan distance.
%   Section F  — Output (path printing / report).
%   Section G  — Sorted-insert helper for the open list.
%   Section H  — TODO (YOUR HALF): heuristic, gbfs, solve.

% ==============================================================


% --------------------------------------------------------------
% SECTION A — GRID FACT
% --------------------------------------------------------------


% Example 1 :
grid([[r, e, d, e, e],
      [e, e, f, e, s],
      [d, e, e, e, d],
      [e, s, e, f, s]]).

% Example 2 :
% grid([[r, e, s],
%       [d, f, e],
%       [e, s, e]]).




% --------------------------------------------------------------
% SECTION C — GRID HELPERS
% --------------------------------------------------------------

% cell_at((R,C), V): cell (R,C) holds value V.
cell_at((R,C), V) :-
    grid(G),
    nth1(R, G, Row),
    nth1(C, Row, V).

% grid_size(Rows, Cols)
grid_size(Rows, Cols) :-
    grid(G),
    length(G, Rows),
    G = [Row1|_],
    length(Row1, Cols).

% in_bounds((R,C))
in_bounds((R,C)) :-
    grid_size(Rows, Cols),
    R >= 1, R =< Rows,
    C >= 1, C =< Cols.

% passable((R,C)): cell is inside the grid and not debris/fire.
passable((R,C)) :-
    in_bounds((R,C)),
    cell_at((R,C), V),
    V \== d,
    V \== f.

% is_survivor((R,C)): cell holds an 's'.
is_survivor((R,C)) :-
    cell_at((R,C), s).

% find_start((R,C)): the unique cell whose value is 'r'.
find_start((R,C)) :-
    cell_at((R,C), r), !.

% all_survivors(Ss): every (R,C) whose cell value is 's'.
all_survivors(Ss) :-
    findall((R,C), cell_at((R,C), s), Ss).


% --------------------------------------------------------------
% SECTION D — MOVES
% --------------------------------------------------------------


neighbor((R,C), (R2,C2)) :-
    (   R2 is R - 1, C2 = C          % up
    ;   R2 is R + 1, C2 = C          % down
    ;   R2 = R,     C2 is C - 1      % left
    ;   R2 = R,     C2 is C + 1      % right
    ),
    passable((R2,C2)).


% --------------------------------------------------------------
% SECTION E — SURVIVOR UTILITIES + MANHATTAN DISTANCE
% --------------------------------------------------------------

% manhattan(+P1, +P2, -D): Manhattan distance |dR|+|dC|.
manhattan((R1,C1), (R2,C2), D) :-
    DR is R1 - R2,
    DC is C1 - C2,
    ( DR < 0 -> ADR is -DR ; ADR = DR ),
    ( DC < 0 -> ADC is -DC ; ADC = DC ),
    D is ADR + ADC.

% remaining_survivors(+Collected, -Remaining)
% Remaining = all survivors NOT yet in Collected.
remaining_survivors(Collected, Remaining) :-
    all_survivors(All),
    findall(S, (member(S, All), \+ member(S, Collected)), Remaining).

% min_manhattan(+Pos, +Cells, -D)
% D = minimum Manhattan distance from Pos to any cell in Cells.
% If Cells is [], D = 0 (there is nothing left to chase).
min_manhattan(_, [], 0).
min_manhattan(Pos, [C|Cs], D) :-
    manhattan(Pos, C, D1),
    min_manhattan(Pos, Cs, D2),
    ( Cs == []        -> D = D1
    ; D1 =< D2        -> D = D1
    ;                    D = D2
    ).


% --------------------------------------------------------------
% SECTION F — OUTPUT
% --------------------------------------------------------------

% write_coord((R,C)) — prints "(R,C)".
write_coord((R,C)) :-
    format('(~w,~w)', [R,C]).

% print_path([(R,C), ...]) — prints "(R1,C1) -> (R2,C2) -> ..."
% Expects the forward path (start .. end).
print_path([P]) :- !,
    write_coord(P).
print_path([P|Ps]) :-
    write_coord(P), write(' -> '),
    print_path(Ps).

% report(+ForwardPath, +Collected)
% Prints the three required output lines.
report(ForwardPath, Collected) :-
    length(ForwardPath, L), Steps is L - 1,
    length(Collected, N),
    write('Path found: '), print_path(ForwardPath), nl,
    write('Survivors rescued: '), write(N), nl,
    write('Number of steps: '), write(Steps), nl.


% --------------------------------------------------------------
% SECTION G — SORTED INSERT (for the open list)
% --------------------------------------------------------------
% insert_sorted(+Node, +OpenIn, -OpenOut)
% Inserts node(H,State) into an H-ascending list. Ties keep
% new nodes AFTER existing ones (stable LIFO-ish tie-breaking).

insert_sorted(Node, [], [Node]).
insert_sorted(node(H,S), [node(H2,S2)|Rest], [node(H,S), node(H2,S2)|Rest]) :-
    H < H2, !.
insert_sorted(N, [M|Rest], [M|Rest2]) :-
    insert_sorted(N, Rest, Rest2).


% ==============================================================
% SECTION H — YOUR 50%
% ==============================================================

% --------------------------------------------------------------
% (1) HEURISTIC FUNCTION
% --------------------------------------------------------------

% heuristic(+State, -H)
% H = K * (number of survivors still to collect) + (minimum Manhattan
% distance from current position to the nearest uncollected survivor).
% K = Rows + Cols + 1 makes the "missing survivors" term dominate the
% "distance to next" term, so the search always prefers states that have
% collected more survivors, breaking ties by closeness to the next one.
heuristic(state(Pos, _Path, Collected), H) :-
    grid_size(Rows, Cols),
    K is Rows + Cols + 1,
    remaining_survivors(Collected, Remaining),
    length(Remaining, Missing),
    min_manhattan(Pos, Remaining, MinDist),
    H is K * Missing + MinDist.


% --------------------------------------------------------------
% (2) GREEDY BEST-FIRST SEARCH (GBFS)
% --------------------------------------------------------------

% gbfs(+Open, +Closed, +BestSoFar, -BestState)
%
% Open      : list of node(H, State) sorted ascending by H (lowest = best).
% Closed    : list of positions already expanded (explicit closed list).
% BestSoFar : the richest state seen so far (most survivors collected).
% BestState : the best state found when the search terminates.
%
% Algorithm:
%   1. Pop the head of Open (lowest H — the greedy choice).
%   2. If its position is in Closed (already expanded), skip it.
%   3. Otherwise:
%        a. Update the current collected-survivor set.
%        b. Compare with BestSoFar; keep the one with more survivors.
%        c. Expand passable neighbours that are not in the current path.
%        d. Insert each successor into Open in sorted order.
%   4. When Open is empty, return the accumulated BestSoFar.

% Base case: open list exhausted — return whatever best we have found.
gbfs([], _Closed, Best, Best).

% Skip nodes whose position has already been expanded (closed list check).
gbfs([node(_H, state(Pos, _Path, _Coll))|Rest], Closed, BestSoFar, Best) :-
    member(Pos, Closed), !,
    gbfs(Rest, Closed, BestSoFar, Best).

% Main expansion step.
gbfs([node(_H, State)|Rest], Closed, BestSoFar, Best) :-
    State = state(Pos, Path, Collected),

    % Mark position as expanded.
    NewClosed = [Pos|Closed],

    % Rescue survivor at current cell if present.
    cell_at(Pos, V),
    ( V == s
    -> NewCollected = [Pos|Collected]   % add survivor to collected set
    ;  NewCollected = Collected
    ),

    % Build the state reflecting the newly updated collected set.
    % (Path already has Pos at its head — no need to prepend again.)
    CurrentState = state(Pos, Path, NewCollected),

    % Update best-so-far: keep the state with more rescued survivors.
    BestSoFar = state(_, _, BestColl),
    length(NewCollected, Nc),
    length(BestColl, Nb),
    ( Nc > Nb
    -> NewBest = CurrentState
    ;  NewBest = BestSoFar
    ),

    % Find all passable neighbours not already visited in this path.
    findall(
        NPos,
        ( neighbor(Pos, NPos),
          \+ member(NPos, Path)   % no cell revisits within a single path
        ),
        Successors
    ),

    % Insert successor nodes into Open maintaining heuristic sort order.
    % Pass Path (which already contains Pos) as the ancestor chain so that
    % each successor NPos is stored as state(NPos, [NPos|Path], ...).
    expand_successors(Successors, Path, NewCollected, Rest, NewOpen),

    % Recurse with updated open list, closed list, and best state.
    gbfs(NewOpen, NewClosed, NewBest, Best).


% expand_successors(+Successors, +Path, +Collected, +OpenIn, -OpenOut)
% For each successor position build a state, compute its heuristic, and
% insert it into the open list maintaining sorted (ascending H) order.
expand_successors([], _Path, _Collected, Open, Open).
expand_successors([NPos|Rest], Path, Collected, OpenIn, OpenOut) :-
    NState = state(NPos, [NPos|Path], Collected),
    heuristic(NState, H),
    insert_sorted(node(H, NState), OpenIn, OpenMid),
    expand_successors(Rest, Path, Collected, OpenMid, OpenOut).


% --------------------------------------------------------------
% (3) SOLVE — ENTRY POINT
% --------------------------------------------------------------

% solve/0
% Initialises GBFS from the robot's starting position and prints the
% report for the path that rescued the greatest number of survivors.
%
% The initial BestSoFar is seeded with the start state (0 survivors
% collected) so that any real improvement will immediately dominate.
solve :-
    find_start(Start),

    % Build the initial state: robot at Start, path contains only Start.
    InitState = state(Start, [Start], []),
    heuristic(InitState, H0),
    InitOpen = [node(H0, InitState)],

    % Seed the accumulator with the start state (0 survivors so far).
    InitBest = InitState,

    % Run GBFS; BestState is the state with the most survivors found.
    gbfs(InitOpen, [], InitBest, BestState),

    % The path is stored in reverse order (newest cell first); flip it.
    BestState = state(_FinalPos, ReversePath, Collected),
    reverse(ReversePath, ForwardPath),

    % Print the required report lines.
    report(ForwardPath, Collected).
