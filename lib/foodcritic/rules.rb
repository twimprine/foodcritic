rule "FC001", "Use symbols in preference to strings to access node attributes" do
  description "When accessing node attributes you should use a symbol for a key rather than a string literal."
  recipe do |ast|
    matches = []
    attribute_refs = %w{node default override set normal}
    aref_fields = self.ast(:aref, ast) + self.ast(:aref_field, ast)
    aref_fields.each do |field|
      is_node_aref = attribute_refs.include? self.ast(:@ident, field).flatten.drop(1).first
      if is_node_aref
        literal_strings = self.ast(:@tstring_content, field)
        literal_strings.each do |str|
          matches << {:matched => str[1], :line => str[2].first, :column => str[2].last}
        end
      end
    end
    matches
  end
end

rule "FC002", "Avoid string interpolation where not required" do
  description "When setting a resource value avoid string interpolation where not required."
  recipe do |ast|
    matches = []
    self.ast(:string_literal, ast).each do |literal|
      embed_expr = self.ast(:string_embexpr, literal)
      if embed_expr.size == 1
        literal[1].reject! { |expr| expr == embed_expr.first }
        if self.ast(:@tstring_content, literal).empty?
          self.ast(:@ident, embed_expr).map { |ident| ident.flatten.drop(1) }.each do |ident|
            matches << {:matched => ident[0], :line => ident[1], :column => ident[2]}
          end
        end
      end
    end
    matches
  end
end

rule "FC003", "Check whether you are running with chef server before using server-specific features" do
  description "Ideally your cookbooks should be usable without requiring chef server."
  recipe do |ast|
    matches = []
    function_calls = self.ast(:@ident, self.ast(:fcall, ast)).map { |fcall| fcall.drop(1).flatten }
    searches = function_calls.find_all { |fcall| fcall.first == 'search' }
    unless searches.empty? || checks_for_chef_solo?(ast)
      searches.each { |s| matches << {:matched => s[0], :line => s[1], :column => s[2]} }
    end
    matches
  end
end

rule "FC004", "Use a service resource to start and stop services" do
  description "Avoid use of execute to control services - use the service resource instead."
  recipe do |ast|
    matches = []
    find_resources(ast, 'execute').find_all do |cmd|
      cmd_str = resource_attribute('command', cmd)
      cmd_str = resource_name(cmd) if cmd_str.nil?
      cmd_str.include?('/etc/init.d') || cmd_str.start_with?('service ') || cmd_str.start_with?('/sbin/service ')
    end.each do |service_cmd|
      exec = ast(:@ident, service_cmd).first.drop(1).flatten
      matches << {:matched => exec[0], :line => exec[1], :column => exec[2]}
    end
    matches
  end
end