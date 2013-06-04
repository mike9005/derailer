$gensym = 1
class Object
  $symbolic_execution = false
  $results = []

  # alias :old_send :send
  # def send(meth, *args)
  #   if meth.is_a? Exp then
  #     Exp.new(:unknown, self, :send, meth, *args)
  #   else
  #     old_send(meth, *args)
  #   end
  # end

  def type
    :unknown
  end

  alias :old_instance_variable_get :instance_variable_get
  alias :old_instance_variable_set :instance_variable_set

  def instance_variable_get(var)
    if var.is_a? Exp or var.to_s.starts_with? "@Exp" then
      puts "USING MY instance variable get: " + self.to_s + "." + var.to_s
      var
    else
      self.old_instance_variable_get(var)
    end
  end

  def instance_variable_set(var, val)
    if var.is_a? Exp or var.to_s.starts_with? "@Exp" then
      puts "USING MY instance variable set"
      Exp.new(:nil, self, :instance_variable_set, var, val)
    else
      self.old_instance_variable_set(var, val)
    end
  end

  def self.forall(&block)
    if $symbolic_execution then
      call_forall(block)
    else
      $symbolic_execution = true
      $results << call_forall(block)
      $symbolic_execution = false
    end
  end

  def call_forall(block)
    def mknew(n, k)
      vars = []
      (1..n).each do
        vars << Exp.new(k, k)
      end
      vars
    end

    klass = self

    if block.arity == -1 then
      vars = []
      result = block.call
    elsif block.arity == 1 then
      vars = mknew(1, klass)
      result = block.call(vars[0])
    elsif block.arity == 2 then
      vars = mknew(2, klass)
      result = block.call(vars[0], vars[1])
    else raise "error: forall called with more than two quantified vars"
    end


    vars.each do |v|
      metaklass = class << v; self; end

      name = "var" + $gensym.to_s
      $gensym = $gensym + 1

      metaklass.send(:define_method, :to_alloy, lambda { name })
    end

    # $objects_used = $objects_used + vars
    # $latest_objects = vars
    Exp.new(:forall, vars, result)
  end

  # alias :old_send :send

  # def send(m, *args)
  #   if m.is_a? Exp then
  #     Exp.new(m.type, self, m, *args)
  #   else
  #     old_send(m, *args)
  #   end
  # end

end

class Array
  alias :old_join :join

  def join(str="")
    if self.index{|x| x.is_a? Exp} then
      Exp.new(:string, self, :join, str)
    else
      self.old_join(str)
    end
  end
end

class SymbolicArray < Array
  def initialize
    @my_objs = Hash.new
  end

  def join(str)
    Exp.new(:string, :join, self, str)
  end

  def [](key)
    if @my_objs.has_key? key
      @my_objs[key]
    else
      o = Exp.new(:params, key)
      @my_objs[key] = o
      o
    end
  end

  # THIS IS PROBABLY WRONG!
  def method_missing(*args)
    #puts "called it " + args.to_s
    Exp.new(self, *args)
  end
end

# todo: more stuff should go here...
class SymbolicHash < Hash
  def initialize(contents)
    @contents = contents
  end

  def to_s
    "SymbolicHash(" + @contents.to_s + ")"
  end
end

class Exp
  def initialize(type, *args)
    @type = type
    @args = args
    @constraints = []

    @args.each do |arg|
      if arg.is_a? Exp and arg.constraints != [] then
        puts "WOOP transfer constraint " 
        arg.constraints.each {|x| add_constraint(x)}
      end
    end
  end

  def class
    Exp.new(:Class, self, 'class')
  end

  def constraints
    @constraints
  end

  def add_constraint(constraint)
    @constraints << constraint
  end

  def type
    @type
  end

  def coerce(other)
    puts "COERCING " + self.to_s + ", other: " + other.to_s
    [other, :unknown]
  end

  def method
    Exp.new(@type, self, :method)
  end

  # def is_a? other
  #   Exp.new(:bool, self, other)
  # end

  def sort
    self
  end

  def find(query)
    Exp.new(@type, self, :query, query)
  end

  def to_descc
    @args[0].to_alloy + " : " + @type.to_alloy
  end

  def to_desc
    self.to_alloy + " : " + @type.to_s
  end
  
  def method_missing(meth, *args, &block)
    if @type.respond_to?(:method_defined?) and @type.method_defined?(meth) then
      @type.new.send(meth, *args)
    else
      Exp.new(@type, self, meth, *args)
    end
  end

  def to_hash
    SymbolicHash.new(self)
  end

  def to_ary
    SymbolicArray.new
  end
  alias :to_a :to_ary
  
  alias :to_str :to_s
  def to_s
    # to eliminate some stuff that we don't want in results
    def is_bad? str
      ['new', 'to_key', 'errors', 'model_name'].each do |bad_str|
        return true if str.include? bad_str
      end
      return false
    end

    if $track_to_s then
      $track_to_s = false
      result = "Exp(" + @type.to_s + ", " + @args.map{|x| x.to_s}.join(", ") + ")"
      $track_to_s = true
      # TODO eliminating everything with "new" might be overkill
      $to_s_exps << self unless self.type == :unused or is_bad? result
    else
      result = "Exp(" + @type.to_s + ", " + @args.map{|x| x.to_s}.join(", ") + ")"
    end
    result
  end

  def ==(other)
    Exp.new(:bool, self, :==, other)
  end

  def implies(&block)
    Exp.new(:bool, self, :implies, block.call)
  end
end

class Choice < Exp
  def initialize
    # nothing
  end
end

# debatable whether or not this is a good idea....
class Class
  def find_by_api_key(key)
    "to_s"
  end
end

class Hash
  alias :old_v :[]
  # alias :old_init :initialize

  # def initialize(*args)
  #   if args.index{|v| v.is_a? Exp} then
  #     puts "IN SECOND"
  #     Exp.new(:Hash, args)
  #   else
  #     puts "IN FIRST " + args.to_s
  #     old_init(*args)
  #   end
  # end
  
  def [](obj)
    if obj.is_a? Exp then
      Exp.new(:new_hash, obj)
    else
      self.old_v(obj)
    end
  end
end


class Fixnum
  alias :old_plus :+
  
  def +(other)
    if other.is_a? Exp then
      Exp.new(:plus, self, other)
    else
      self.old_plus(other)
    end
  end
end
