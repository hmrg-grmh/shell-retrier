# Shell Retrier



## 前提

示例有这样一个功能

~~~ sh
get_jmsgpart_by_api_ ()
{
    api_k="${1:-services/-1}" &&
    add_k ()
    {
        got_j_byk="${1}" &&
        api_k="${2:-$api_k}" &&
        echo "'$api_k': $got_j_byk" ;
    } &&
    
    curl -sS -v -X POST "https://$someapiurl/api"/users/login --data '{"userName": "foo", "userPassword": "bar"}' -c /dev/stdout |
        curl -sS -v -X GET "https://$someapiurl/api"/"$api_k" -b /dev/stdin |
        (let_j_got="$(cat /dev/stdin|jq -c)" && add_k "$let_j_got") ;
} ;
~~~

它的使用是在确保 `$someapiurl` 有意义的情况下，像这样用，来获取对应的 `api_k` 的 Json 格式信息：

~~~ sh
get_jmsgpart_by_api_ service/1153
~~~

它的效果是向标准输出怼入像这样的字符串：

~~~~
'service/1153': {"name":"Killer Queen !!","code":1153,...}
~~~~


