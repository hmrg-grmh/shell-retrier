retrier_sh ()
{
    works_f="${1:-works}" &&
    retried="${2:-0}" &&
    
    export -- works_f retried && export -f -- retrier_sh "$works_f" &&
    
    "$works_f" &&
    { echo :succ :: "$works_f" ,,, "$retried" >&2 ; } ||
    { echo :fail :: "$works_f" ,,, "$retried" >&2 ; exec sh -c ' retrier_sh "$works_f" "$((retried+1))" ' ; } ;
} ;

retrier ()
{
    works_f="${1:-works}" &&
    retried="${2:-0}" &&
    
    "$works_f" &&
    { echo :succ :: "$works_f" ,,, "$retried" >&2 ; } ||
    { echo :fail :: "$works_f" ,,, "$retried" >&2 ; exec sh -c " $(declare -f -- retrier "$works_f") ; 'retrier' '$works_f' '$((retried+1))' " ; } ;
} ;

retrier_x ()
{
    rtr ()
    {
        retried="${1:-0}" && shift &&
        fun_name="${1:-fun}"
        
        "$@" && { echo :succ :: "$fun_name" ,,, "$retried" >&2 ; } ||
        {
            echo :fail :: "$fun_name" ,,, "$retried" >&2 ;
            exec sh -c "$(declare -f -- rtr "$fun_name") ; rtr '$((retried+1))' $* " ;
        } ;
    } && rtr 0 "$@" ;
} ;
