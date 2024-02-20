# Shell Retrier

让一组工作具备失败时重试自己的能力。

## .pre

示例有这样一个功能

~~~ sh
get_jmsg_bykey_ ()
{
    api_k="${1:-services/-1}" &&
    add_k ()
    {
        got_j_byk="${1}" &&
        api_k="${2:-$api_k}" &&
        echo "'$api_k': $got_j_byk" ;
    } &&
    
    curl -sS -v -X POST "https://${someapiurl}/api"/users/login --data '{"userName": "foo", "userPassword": "bar"}' -c /dev/stdout |
        curl -sS -v -X GET "https://${someapiurl}/api"/"$api_k" -b /dev/stdin |
        (let_j_got="$(cat /dev/stdin|jq -c)" && add_k "$let_j_got") ;
} ;
~~~


它的使用是在确保 `$someapiurl` 有意义的情况下，像这样用，来获取对应的 `api_k` 的 Json 格式信息：

~~~ sh
get_jmsg_bykey_ service/1153
~~~

它的效果是向标准输出怼入像这样的字符串（里面右边的 Json 就是正常通过这个 Key 会获取到的）：

~~~~
'service/1153': {"name":"Killer Queen !!","code":1153,"std":9}
~~~~

在本工具中，可以把它作为上面所说的那「一组工作」的一部分使用。

*上面的功能的代码不必仔细看，就是几个 `curl` 命令，用于最终获取 Json 的。重点就是，实际使用时，它是可能会失败的。它可以被用来测试下面的工具。*

*所谓「一组工作」其实就是**一个不使用位置参数的SHELL函数**。*

## .self

### .posix_local

#### .def

增加如下定义：

~~~~ sh
retrier_sh ()
{
    works_f="${1:-works}" &&
    retried="${2:-0}" &&
    
    export -- works_f retried && export -f -- retrier_sh "$works_f" &&
    
    "$works_f" &&
    { echo :succ :: "$works_f" ,,, "$retried" >&2 ; } ||
    { echo :fail :: "$works_f" ,,, "$retried" >&2 ; exec sh -c ' retrier_sh "$works_f" "$((retried+1))" ' ; } ;
} ;
~~~~

#### .use-0

使用例：

~~~ sh
(works () { get_jmsg_bykey_ service/1153 ; } && retrier_sh works 2>/dev/null)
# or
works () { get_jmsg_bykey_ service/1153 ; } && (retrier_sh works) 2>/dev/null
~~~

**请注意，这里 被判定若失败则重做的实际是 `works` 。从 `retrier_sh` 的定义可以看出，这里并没有为被传入函数设计可传参数的功能——其实这并不难，我只是想要展示一下现在的情况下可以怎么用。🦥**

**还有，一定要有括号。至少一定让 `retrier_sh works` 在括号里头。至于为啥，最后有个简单的例子，想试的话试试就知道了。。。🙊**

*（上面的 `2>/dev/null` 可以不写但可能会挺乱的。另外，在结尾符 `&&` 后面紧挨着的回车等于空格，所以可以安心换行。）*

#### .use-1

批量使用（示例并发度为 `3` ）：

~~~ sh
export -- someapiurl &&
export -f -- retrier_sh get_jmsg_bykey_ &&

cat <<'APIKEYS' |
service/11
service/12
service/3130
service/7
serviceRoles?serviceId=2&roleType=META&nodeId=2
serviceRoles?serviceId=8&roleType=META&nodeId=5
APIKEYS
    xargs -i -P3 -- sh -c 'works_xrg_ () { get_jmsg_bykey_ {} ; } ; retrier_sh works_xrg_ 2>/dev/null '
~~~


### .remote_declare

上述使用 `export` 确保变量或函数在 *子进程* 中的有效。

还可以使用另一种方式，其性能不如前者，但它能将定义带到别的机器。

这个办法就是 `declare` ，对于 `bash` 它是内置命令。~~在 `sh` 里没有这个东西。~~（后来试了试有有了，这是什么情况。。。所以说下面代码用 `exec sh` 没问题。）

#### .def

~~~~ bash
retrier ()
{
    works_f="${1:-works}" &&
    retried="${2:-0}" &&
    
    "$works_f" &&
    { echo :succ :: "$works_f" ,,, "$retried" >&2 ; } ||
    { echo :fail :: "$works_f" ,,, "$retried" >&2 ; exec sh -c " $(declare -f -- retrier "$works_f") ; 'retrier' '$works_f' '$((retried+1))' " ; } ;
} ;
~~~~

可以对比一下变化的部分：

- `export` 变量被双引号应用变量代替
- `export` 函数被 `declare -f fun_name` 代替

别的则并没什么变化。

#### .uses

使用（批量）：

~~~ sh
cat <<'APIKEYS' |
service/11
service/12
service/3130
service/7
serviceRoles?serviceId=2&roleType=META&nodeId=2
serviceRoles?serviceId=8&roleType=META&nodeId=5
APIKEYS
    xargs -i -P1 -- ssh $some_ip -- " $(declare -f -- retrier get_jmsg_bykey_) ; works_xrg_ () { someapiurl='$someapiurl' && get_jmsg_bykey_ {} ; } ; retrier_sh works_xrg_ 2>/dev/null "
~~~

在变量 `some_ip` 的值在此有意义时，这样做可以让 `some_ip` 那台机器上被远程执行 `get_jmsg_bykey_` ，批量（这次并发是 `1` ）、且非本地地执行。

## points

重试的要点就是 ***递归*** 。这里尝试把 SHELL 上的函数像 *first-class function* 一样用，实际上只是把函数名像传入任何字符串一样传入，然后在一些**非当前SHELL的环境**下，想办法（ `export -f` 或 `declare -f` ）用上它的定义罢了。

这里营造了一种**好像**（因为它是强制的） *尾递归* 一样的效果，是用 `exec` 达到的。这个 `exec` 能够让它之后的命令不管有没有都失效，也就是一律不保存函数剩下的信息，**不论还有没有**，整个外层函数都会被完全**覆盖**掉。因此，也就不会出现类似于「爆栈」的事情了。

*（高版本 `bash` 已经能够不会被这种过多的函数调用搞出「爆栈」效果了，它会给个警告信息然后主动丢掉之前压在「栈」里的信息，从而再也不怕被搞大啦。。。（？））*

### .x

#### .def

再示例一个可传参函数更便捷地使用的 `retrier` 定义：

~~~~ bash
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
~~~~

#### .uses

试试看：

~~~ bash
(retrier_x cd xxx)
~~~

或者：

~~~ bash
retrier_x cd xxx &
~~~

然后在一片混乱中尝试粘贴这个来停止这鬼畜的混乱：

~~~ sh
mkdir xxx
~~~

办法肯定不光这一个，这个办法的问题就在于传入参数复杂一点的话就会在 $* 那里不好整。

其实也可以支持**传入一个字符串整个当命令**，比如一个能够像这样用的定义： `retrier_r 'cd xxx'` ，但如果要这样的话，我觉得还不如前面弄个 `works` 的做法好使……

另外，上面那个其实也可以把 `declare` 的部分改成用 `export` 的，可以提高性能（鬼畜的时候也会更鬼畜），这个我就不示例了……太晚了得吃饭去了……

## .dl

~~~ sh
wget https:ghproxy.com/https://github.com/hmrg-grmh/shell-retrier/raw/main/rtr_funs.sh
~~~
