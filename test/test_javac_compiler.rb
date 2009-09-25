$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'duby'
require 'duby/jvm/source_compiler'
require 'jruby'
require 'stringio'
require File.join(File.dirname(__FILE__), 'test_jvm_compiler')

class TestJavacCompiler < TestJVMCompiler
  import javax.tools.ToolProvider
  import java.util.Arrays
  def javac(files)
    compiler = ToolProvider.system_java_compiler
    fm = compiler.get_standard_file_manager(nil, nil, nil)
    units = fm.get_java_file_objects_from_strings(Arrays.as_list(files.to_java :string))
    unless compiler.get_task(nil, fm, nil, nil, nil, units).call
      raise "Compilation error"
    end
    loader = org.jruby.util.ClassCache::OneShotClassLoader.new(
        JRuby.runtime.jruby_class_loader)
    classes = []
    files.each do |name|
      classfile = name.sub /java$/, 'class'
      if File.exist? classfile
        bytecode = IO.read(classfile)
        cls = loader.define_class(name[0..-6], bytecode.to_java_bytes)
        classes << JavaUtilities.get_proxy_class(cls.name)
        @tmp_classes << name
        @tmp_classes << classfile 
      end
    end
    classes
  end
  
  def compile(code)
    File.unlink(*@tmp_classes)
    @tmp_classes.clear
    AST.type_factory = Duby::JVM::Types::TypeFactory.new
    ast = AST.parse(code)
    compiler = Compiler::JavaSource.new("script#{System.nano_time.to_s}")
    typer = Typer::JVM.new(compiler)
    ast.infer(typer)
    typer.resolve(true)
    ast.compile(compiler, false)
    java_files = []
    compiler.generate do |name, builder|
      bytes = builder.generate
      open("#{name}", "w") do |f|
        f << bytes
      end
      java_files << name
    end
    classes = javac(java_files)
  end
end