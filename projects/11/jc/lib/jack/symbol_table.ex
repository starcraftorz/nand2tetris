defmodule Jack.SymbolTable do
  def resolve(ast) do
    {ast, _symbols} = replace(ast, %{"class" => nil, "field" => %{}, "static" => %{}, "argument" => %{}, "var" => %{}})
    ast
  end

  defp replace([{:keyword, "class"},{:identifier, id}|rest], symbols) do
    id_map = %{:name => id, :category => "class", :definition => true}
    list = [keyword: "class", identifier: id_map]
    symbols = Dict.put(symbols, "class", id)
    {rest, symbols} = replace(rest, symbols)
    {list ++ rest, symbols}
  end
  defp replace([{:classVarDec,dec}|rest], syms) do
    {dec, syms} = cvd(dec,syms,%{})
    {rest,syms} = replace(rest, syms)
    {[{:classVarDec,dec}|rest],syms}
  end
  defp replace([{:subroutineDec,dec}|rest], syms) do
    {dec, _sub_syms} = sub(dec,syms)
    {rest,syms} = replace(rest, syms)
    {[{:subroutineDec,dec}|rest],syms}
  end
  defp replace([],symbols) do
    {[], symbols}
  end
  defp replace([head|tail], symbols) do
    {tail, symbols} = replace(tail, symbols)
    {[head|tail], symbols}
  end

  defp cvd([], syms, _temp), do: {[], syms}
  defp cvd([{:keyword, kw},type|tail], syms, temp) when (kw in ["field","static"]) do
    temp = Dict.put_new(temp, :category, kw)
    {_,type_str} = type
    temp = Dict.put_new(temp, :type, type_str)
    {tail, syms} = cvd(tail, syms, temp)
    {[{:keyword, kw},type|tail],syms}
  end
  defp cvd([{:identifier,id}|tail], syms, %{:category => c}=temp) do
    idx = syms |> Dict.get(c) |> Dict.size
    id_map = Dict.merge(temp, %{ :name => id, :definition => true, :index => idx })
    syms = Dict.update!(syms, c, &(Dict.put_new(&1,id,id_map)))
    {tail, syms} = cvd(tail, syms, temp)
    {[{:identifier, id_map}|tail], syms}
  end
  defp cvd([head|tail], syms, temp) do
    {tail, syms} = cvd(tail, syms, temp)
    {[head|tail], syms}
  end

  defp sub([], syms), do: {[], syms}
  defp sub([{:keyword,"function"},type,{:identifier,id}|tail], syms) do
    %{"class" => class} = syms
    {tail,syms} = sub(tail, syms)
    local_vars = syms |> Dict.get("var") |> Dict.size
    id_map = %{:name => id, :category => "subroutine", :definition => true, :class => class, :local_vars => local_vars}
    {[{:keyword,"function"},type,{:identifier, id_map}|tail], syms}
  end
  defp sub([{:keyword,"method"},type,{:identifier,id}|tail], syms) do
    %{"class" => class} = syms
    this = %{:name => "this", :category => "argument", :index => 0, :definition => true, :type => class}
    syms = Dict.update!(syms, "argument", &(Dict.put_new(&1,"this",this)))
    {tail,syms} = sub(tail, syms)
    local_vars = syms |> Dict.get("var") |> Dict.size
    id_map = %{:name => id, :category => "method", :definition => true, :class => class, :local_vars => local_vars}
    {[{:keyword,"method"},type,{:identifier, id_map}|tail], syms}
  end
  defp sub([{:keyword,"constructor"},type,{:identifier,id}|tail], %{"class" => class} = syms) do
    {tail,syms} = sub(tail, syms)
    local_vars = syms |> Dict.get("var") |> Dict.size
    instance_vars = syms |> Dict.get("field") |> Dict.size
    id_map = %{:name => id, :category => "constructor", :definition => true, :class => class, :local_vars => local_vars, :instance_vars => instance_vars}
    {[{:keyword,"constructor"},type,{:identifier, id_map}|tail], syms}
  end
  defp sub([{:parameterList,params}|tail], syms) do
    {params, syms} = params(params,syms)
    {tail,syms} = sub(tail, syms)
    {[{:parameterList,params}|tail], syms}
  end
  defp sub([{:subroutineBody,body}|tail], syms) do
    {body, syms} = body(body,syms)
    {tail,syms} = sub(tail,syms)
    {[{:subroutineBody,body}|tail], syms}
  end
  defp sub([head|tail], syms) do
    {tail, syms} = sub(tail, syms)
    {[head|tail], syms}
  end

  defp params([],syms), do: {[],syms}
  defp params([type,{:identifier, id}|tail],syms) do
    idx = syms |> Dict.get("argument") |> Dict.size
    {_,type_str} = type
    id_map = %{:name => id, :category => "argument", :index => idx, :definition => true, :type => type_str}
    syms = Dict.update!(syms, "argument", &(Dict.put_new(&1,id,id_map)))
    {tail, syms} = params(tail, syms)
    {[type,{:identifier,id_map}|tail], syms}
  end
  defp params([head|tail], syms) do
    {tail, syms} = params(tail, syms)
    {[head|tail], syms}
  end

  defp body([],syms), do: {[],syms}
  defp body([{:varDec,dec}|tail], syms) do
    {dec, syms} = vd(dec, syms, %{})
    {tail, syms} = body(tail, syms)
    {[{:varDec,dec}|tail],syms}
  end
  defp body([{:statements,statements}|tail], syms) do
    {statements, syms} = statements(statements, syms)
    {tail, syms} = body(tail, syms)
    {[{:statements, statements}|tail],syms}
  end
  defp body([head|tail], syms) do
    {tail,syms} = body(tail, syms)
    {[head|tail], syms}
  end

  defp vd([], syms, _temp), do: {[], syms}
  defp vd([{:keyword, "var"},type|tail], syms, temp) do
    {_,type_str} = type
    temp = Dict.put_new(temp, :type, type_str)
    {tail, syms} = vd(tail, syms, temp)
    {[{:keyword, "var"},type|tail],syms}
  end
  defp vd([{:identifier,id}|tail], syms, temp) do
    idx = syms |> Dict.get("var") |> Dict.size
    id_map = Dict.merge(temp, %{ :category => "var", :name => id, :definition => true, :index => idx })
    syms = Dict.update!(syms, "var", &(Dict.put_new(&1,id,id_map)))
    {tail, syms} = vd(tail, syms, temp)
    {[{:identifier, id_map}|tail], syms}
  end
  defp vd([head|tail], syms, temp) do
    {tail, syms} = vd(tail, syms, temp)
    {[head|tail], syms}
  end

  defp statements([],syms) do
    {[],syms}
  end
  defp statements([{type,list}|tail], syms) when is_list(list) do
    {list,syms} = statements(list, syms)
    {tail,syms} = statements(tail, syms)
    {[{type,list}|tail], syms}
  end
  defp statements([{:identifier,receiver},{:symbol,"."},{:identifier,method},{:symbol,"("}|tail], syms) do
    [{:expressionList,list}|_] = tail
    explicit_args = div(Enum.count(list)+1,2)
    method_map = %{:name => method, :category => "subroutine", :definition => false, :numArgs => explicit_args}
    method_map = case resolve_or_class(receiver,syms) do
      %{category: "class", name: class} -> Dict.merge(method_map, %{class: class})
      %{type: type} = id -> Dict.merge(method_map, %{class: type, receiver: id, numArgs: explicit_args + 1})
    end
    {tail, syms} = statements(tail, syms)
    {[{:identifier, method_map},{:symbol,"("}|tail],syms}
  end
  defp statements([{:identifier,id},{:symbol,"("}|tail], %{"class" => class} = syms) do
    [{:expressionList,list}|_tt] = tail
    explicit_args = div(Enum.count(list)+1,2)
    id_map = %{:name => id, :category => "subroutine", :class => class, :definition => false, :numArgs => explicit_args + 1, :receiver => :this}
    {tail, syms} = statements(tail, syms)
    {[{:identifier, id_map},{:symbol,"("}|tail],syms}
  end
  defp statements([{:identifier, id}|tail], syms) do
    id_map = resolve!(id, syms)
    id_map = %{id_map| definition: false}
    {tail, syms} = statements(tail, syms)
    {[{:identifier,id_map}|tail], syms}
  end
  defp statements([head|tail],syms) do
    {tail,syms} = statements(tail, syms)
    {[head|tail],syms}
  end

  defp resolve!(identifier, syms) do
    case resolve(identifier, syms) do
      nil -> raise ArgumentError, "could not resolve #{identifier}"
      val -> val
    end
  end
  defp resolve(identifier, %{"var" => vars, "argument" => arguments, "field" => fields, "static" => statics}) do
    [vars, arguments, fields, statics] |>
      Enum.map( &(Dict.get(&1,identifier)) ) |>
      Enum.reject( &(&1 == nil) ) |>
      List.first
  end

  defp resolve_or_class(identifier, syms) do
    case resolve(identifier,syms) do
      nil -> %{:name => identifier, :category => "class", :definition => false}
      id_map -> %{id_map | definition: false}
    end
  end
end
