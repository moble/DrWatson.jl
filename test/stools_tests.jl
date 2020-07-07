using DrWatson, Test

# Test commit function
com = gitdescribe(@__DIR__)
@test com isa String

com = gitdescribe(dirname(@__DIR__))
@test com !== nothing
@test typeof(com) <: String
@test com[1] == 'v' # test that it has a version tag
# tag!
d1 = Dict(:x => 3, :y => 4)
d2 = Dict("x" => 3, "y" => 4)
for d in (d1, d2)
    d = tag!(d, gitpath=@__DIR__)

    @test haskey(d, keytype(d)(:gitcommit))
    @test d[keytype(d)(:gitcommit)] |> typeof <: String
end

# @tag!
for d in (d1, d2)
    d = @tag!(d, gitpath=@__DIR__)
    @test haskey(d, keytype(d)(:gitcommit))
    @test d[keytype(d)(:gitcommit)] |> typeof <: String
    @test split(d[keytype(d)(:script)], '#')[1] == basename(@__FILE__)
end

# Tag kw-functions

d = Dict(:x => 3, :y => 4)
d_new = tag!(d)

@test d == d_new

d_new = tag!(d,gitpath=@__DIR__,source="foo")
@test endswith(d_new[:script],"foo")

d_new = @tag!(d,gitpath=@__DIR__)
@test split(d_new[keytype(d_new)(:script)], '#')[1] == basename(@__FILE__)

ex = @macroexpand @tag!(d,gitpath="path")

@test ex.args[1].name == :tag!
@test ex.args[2] == :d
@test ex.args[3].head == :kw
@test ex.args[3].args[1] == :gitpath
@test ex.args[3].args[2] == "path"
@test ex.args[4].head == :kw

# Test force kw

d = Dict(:x => 3, :y => 4, :gitcommit => "")
@test tag!(d,gitpath=@__DIR__)[:gitcommit] == ""
@test tag!(d,gitpath=@__DIR__,force=true)[:gitcommit] == com
d = Dict(:x => 3, :y => 4, :gitcommit => "")
@test (@tag!(d, gitpath=@__DIR__,force=true))[:gitcommit] == com

# Test dictionary expansion
c = Dict(:a => [1, 2], :b => 4);
c1 = [ Dict(:a=>1,:b=>4)
 Dict(:a=>2,:b=>4)]

v1 = dict_list(c)
for el in c1
    @test el ∈ v1
end
@test keytype(eltype(v1)) == Symbol

c[:c] = "test"; c[:d] = ["lala", "lulu"];
c2 = [ Dict(:a=>1,:b=>4,:d=>"lala",:c=>"test")
 Dict(:a=>2,:b=>4,:d=>"lala",:c=>"test")
 Dict(:a=>1,:b=>4,:d=>"lulu",:c=>"test")
 Dict(:a=>2,:b=>4,:d=>"lulu",:c=>"test")]

v2 = dict_list(c)
for el in c2
    @test el ∈ v2
end
@test keytype(eltype(v2)) == Symbol

c[:e] = [[1, 2], [3, 5]];
c3 = [
Dict(:a=>1,:b=>4,:d=>"lala",:e=>[1, 2],:c=>"test")
Dict(:a=>2,:b=>4,:d=>"lala",:e=>[1, 2],:c=>"test")
Dict(:a=>1,:b=>4,:d=>"lulu",:e=>[1, 2],:c=>"test")
Dict(:a=>2,:b=>4,:d=>"lulu",:e=>[1, 2],:c=>"test")
Dict(:a=>1,:b=>4,:d=>"lala",:e=>[3, 5],:c=>"test")
Dict(:a=>2,:b=>4,:d=>"lala",:e=>[3, 5],:c=>"test")
Dict(:a=>1,:b=>4,:d=>"lulu",:e=>[3, 5],:c=>"test")
Dict(:a=>2,:b=>4,:d=>"lulu",:e=>[3, 5],:c=>"test")
]

v3 = dict_list(c)
@test dict_list_count(c) == length(c3) == length(v3)
for el in c3
    @test el ∈ v3
end
@test keytype(eltype(v3)) == Symbol

v4 = dict_list(Dict(:a => 1, :b => 2.0)) # both non-iterable
@test keytype(eltype(v4)) == Symbol

v5 = dict_list(Dict(:a => [1], :b => 2.0)) # one non-iterable
@test keytype(eltype(v5)) == Symbol

v6 = dict_list(Dict(:a => [1], :b => [2.0])) # both iterable
@test keytype(eltype(v6)) == Symbol

struct SolverA end
struct SolverB end

# Simple example with no chained dependencies

p = Dict(:α => 1,
         :solver => [SolverA,SolverB],
         :c => @onlyif(:solver == SolverA , [100,200]),
         :d => @onlyif(:solver == SolverB, 1)
        )

@test Set([ Dict(:α => 1, :solver => SolverA, :c => 100),
           Dict(:α => 1, :solver => SolverA, :c => 200),
           Dict(:α => 1, :solver => SolverB, :d => 1),
          ]) == Set(dict_list(p))

p = Dict(:α => 1,
         :solver => [SolverA,SolverB],
         :c => @onlyif(:solver == SolverA , [100,200]),
         :d => @onlyif(:c == 100, 1)
        )

@test Set([
           Dict(:α => 1, :solver => SolverA, :c => 100, :d => 1),
           Dict(:α => 1, :solver => SolverA, :c => 200),
           Dict(:α => 1, :solver => SolverB),
          ]) == Set(dict_list(p))

# Advanced defintions
test_param = @onlyif(begin
                d = Dict( :f => (conds...)->all(conds) )
                cond1 = :b == :c
                cond2 = :d == :something
                cond3 = "d" == :d
                cond4 = :α^2 == 1
                return d[:f](cond1, cond2, cond3, cond4)
            end, nothing)

@test test_param.condition(Dict(:α=>1, :b=>1, :c=>1, :d=>:something, "d"=>:something))
@test !test_param.condition(Dict(:α=>2, :b=>1, :c=>1, :d=>:something, "d"=>:something))
@test !test_param.condition(Dict(:α=>1, :b=>2, :c=>1, :d=>:something, "d"=>:something))
@test !test_param.condition(Dict(:α=>1, :b=>1, :c=>1, :d=>:foo, "d"=>:something))
@test !test_param.condition(Dict(:α=>1, :b=>1, :c=>1, :d=>:something, "d"=>:foo))

### tmpsave ###
tmpdir = joinpath(@__DIR__, "tmp")
ret = tmpsave(v3, tmpdir)
for r in ret
    @test isfile(joinpath(tmpdir, r))
    a = load(joinpath(tmpdir, r))
    @test a ∈ v3
end
rm(tmpdir, force = true, recursive = true)
@test !isdir(tmpdir)
