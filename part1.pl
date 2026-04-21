% cell value at (Row, Col)
cell_value(Grid, Row, Col, Value) :-
    nth1(Row, Grid, GridRow),
    nth1(Col, GridRow, Value).

% grid dimensions
grid_size(Grid, Rows, Cols) :-
    length(Grid, Rows),
    Grid = [FirstRow|_],
    length(FirstRow, Cols).

in_bounds(Grid, Row, Col) :-
    grid_size(Grid, Rows, Cols),
    Row >= 1, Row =< Rows,
    Col >= 1, Col =< Cols.

passable(Grid, Row, Col) :-
    cell_value(Grid, Row, Col, V),
    V \= d, V \= f.

move(pos(R,C), pos(NR,C)) :- NR is R - 1.
move(pos(R,C), pos(NR,C)) :- NR is R + 1.
move(pos(R,C), pos(R,NC)) :- NC is C - 1.
move(pos(R,C), pos(R,NC)) :- NC is C + 1.

is_goal(Grid, pos(R,C)) :-
    cell_value(Grid, R, C, s).

% find robot starting position
find_robot([Row|_], RowIdx, pos(RowIdx, ColIdx)) :-
    nth1(ColIdx, Row, r), !.
find_robot([_|Rest], RowIdx, Pos) :-
    Next is RowIdx + 1,
    find_robot(Rest, Next, Pos).

% get all valid unvisited neighbours of CurrentPos
get_successors(Grid, CurrentPos, CurrentPath, OpenList, ClosedList, Successors) :-
    findall(
        node(NextPos, [NextPos | CurrentPath]),
        (
            move(CurrentPos, NextPos),
            NextPos = pos(NR, NC),
            in_bounds(Grid, NR, NC),
            passable(Grid, NR, NC),
            \+ member(NextPos, ClosedList),
            \+ member(node(NextPos, _), OpenList)
        ),
        Successors
    ).

% Base case: front of OpenList is the goal
bfs(Grid, [node(CurrentPos, ReversedPath) | _], _, ReversedPath) :-
    is_goal(Grid, CurrentPos), !.

% Recursive case: expand front node, update OpenList and ClosedList
bfs(Grid, [node(CurrentPos, CurrentPath) | RestOfOpenList], ClosedList, FinalPath) :-
    get_successors(Grid, CurrentPos, CurrentPath, RestOfOpenList, ClosedList, Successors),
    NewClosedList = [CurrentPos | ClosedList],
    append(RestOfOpenList, Successors, NewOpenList),
    bfs(Grid, NewOpenList, NewClosedList, FinalPath).

% print path
print_path([pos(R,C)]) :-
    format("(~w,~w)", [R, C]).
print_path([pos(R,C) | Rest]) :-
    Rest \= [],
    format("(~w,~w) -> ", [R, C]),
    print_path(Rest).

% entry point - Grid is passed as argument
solve(Grid) :-
    find_robot(Grid, 1, StartPos),
    InitialOpenList  = [node(StartPos, [StartPos])],
    InitialClosedList = [],
    ( bfs(Grid, InitialOpenList, InitialClosedList, ReversedPath)
    ->
        reverse(ReversedPath, Path),
        length(Path, Len),
        Steps   is Len - 1,
        Battery is 100 - Steps * 10,
        format("~nPath found: "),
        print_path(Path),
        format("~nNumber of steps: ~w~n", [Steps]),
        format("Remaining Battery: ~w%~n", [Battery])
    ;
        format("No path to any survivor found.~n")
    ).

% run example grids
:- initialization(main, main).

main :-
    format("=== Example 1 (4x5) ===~n"),
    Grid1 = [[r,e,d,e,e],
             [e,e,f,e,s],
             [d,e,e,e,e],
             [e,e,s,f,e]],
    solve(Grid1),

    format("~n=== Example 2 (3x3) ===~n"),
    Grid2 = [[r,e,e],
             [d,f,e],
             [e,e,s]],
    solve(Grid2),

    format("~n=== Example 3 (3x3) ===~n"),
    Grid3 = [[r,e,e],
             [d,f,e],
             [e,e,e]],
    solve(Grid3),

        format("~n=== Example 4 (3x3) ===~n"),
    Grid4 = [[s,e,e],
             [d,f,e],
             [e,e,r]],
    solve(Grid4).