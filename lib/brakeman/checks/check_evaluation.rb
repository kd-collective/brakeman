require 'brakeman/checks/base_check'

#This check looks for calls to +eval+, +instance_eval+, etc. which include
#user input.
class Brakeman::CheckEvaluation < Brakeman::BaseCheck
  Brakeman::Checks.add self

  @description = "Searches for evaluation of user input"

  #Process calls
  def run_check
    Brakeman.debug "Finding eval-like calls"
    calls = tracker.find_call methods: [:eval, :instance_eval, :class_eval, :module_eval], nested: true

    Brakeman.debug "Processing eval-like calls"
    calls.each do |call|
      process_result call
    end
  end

  #Warns if eval includes user input
  def process_result result
    return unless original? result

    if input = include_user_input?(result[:call].arglist)
      confidence = :high
      message = msg(msg_input(input), " evaluated as code")
    elsif string_evaluation? result[:call].first_arg
      confidence = :low
      message = "Dynamic string evaluated as code"
    elsif safe_literal? result[:call].first_arg
      # don't warn
    elsif result[:call].method == :eval
      confidence = :low
      message = "Dynamic code evaluation"
    end

    if confidence
      warn :result => result,
        :warning_type => "Dangerous Eval",
        :warning_code => :code_eval,
        :message => message,
        :user_input => input,
        :confidence => confidence,
        :cwe_id => [913, 95]
    end
  end

  def string_evaluation? exp
    (string_interp? exp and not all_safe_interp_values? exp) or
      (call? exp and string? exp.target)
  end

  def all_safe_interp_values? exp
    exp.all? do |e|
      if sexp? e
        safe_interp_value? e
      else
        true # not an s-exp
      end
    end
  end

  def safe_interp_value? exp
    case exp.sexp_type
    when :evstr
      safe_interp_value? exp.value
    when :str, :lit
      true
    when :call
      always_safe_method? exp.method
    else
      false
    end
  end
end
