def arcsin(q:!ℝ) lifted :!ℝ;
def sqrt(q:!ℝ) lifted :!ℝ;

def WState[n:!N](q0:𝔹,q1s:𝔹^n) mfree {
    if n+1==1{
        q0 := X(q0);
    } else {
        theta := arcsin(1.0 / sqrt(n));
        q0 := rotY(2*theta, q0);

        if !q0{
            (q1s[0], q1s[1..n]) := WState[n-1](q1s[0], q1s[1..n]);
        }
    }
    return (q0, q1s);
}

def solve(q0:𝔹,q1:𝔹) {
    t := 0:𝔹;
    (q0, (q1, t)) := WState(q0, (q1, t));
    if ((q0, q1) == (0,0)){
        t := X(t);
    }
    return (q0, q1);
}
