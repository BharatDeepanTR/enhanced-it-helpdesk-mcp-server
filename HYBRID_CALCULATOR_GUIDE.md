# Hybrid Calculator Gateway Usage Guide

## Overview
Your enhanced gateway now supports THREE different calculation approaches:

### 1. Lambda MCP Calculator (`target-lambda-direct-calculator-mcp`)
**Best for:** Fast, precise, structured calculations

**Tools Available:**
- `target-lambda-direct-calculator-mcp___add`
- `target-lambda-direct-calculator-mcp___subtract` 
- `target-lambda-direct-calculator-mcp___multiply`
- `target-lambda-direct-calculator-mcp___divide`

**Example Request:**
```json
{
  "jsonrpc": "2.0", 
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-calculator-mcp___add",
    "arguments": {
      "a": 25,
      "b": 4
    }
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "29"
      }
    ]
  },
  "id": 1
}
```

### 2. Bedrock AI Calculator (`target-bedrock-claude-calculator`)
**Best for:** Natural language, complex calculations, explanations

**Example Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 2, 
  "method": "tools/call",
  "params": {
    "name": "target-bedrock-claude-calculator",
    "arguments": {
      "prompt": "Calculate the monthly payment for a $50,000 loan at 4.5% annual interest for 5 years, compounded monthly. Show your work."
    }
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text", 
        "text": "To calculate the monthly payment for this loan, I'll use the loan payment formula:\n\nM = P × [r(1+r)^n] / [(1+r)^n - 1]\n\nWhere:\n- P = Principal loan amount = $50,000\n- r = Monthly interest rate = 4.5% ÷ 12 = 0.045 ÷ 12 = 0.00375\n- n = Total number of payments = 5 years × 12 months = 60\n\nStep 1: Calculate (1+r)^n\n(1 + 0.00375)^60 = (1.00375)^60 = 1.2516\n\nStep 2: Calculate the numerator\nr(1+r)^n = 0.00375 × 1.2516 = 0.004694\n\nStep 3: Calculate the denominator\n(1+r)^n - 1 = 1.2516 - 1 = 0.2516\n\nStep 4: Calculate the monthly payment\nM = $50,000 × (0.004694 ÷ 0.2516) = $50,000 × 0.01866 = $933.09\n\n**Monthly Payment: $933.09**\n\nTotal amount paid: $933.09 × 60 = $55,985.40\nTotal interest paid: $55,985.40 - $50,000 = $5,985.40"
      }
    ]
  },
  "id": 2
}
```

### 3. Application Details (`target-lambda-direct-application-details-mcp`)
**Best for:** Structured data lookup

## When to Use Which Calculator

### Use Lambda MCP Calculator When:
- ✅ You need exact, fast calculations
- ✅ You have structured numeric inputs  
- ✅ You want predictable response format
- ✅ You need to minimize costs
- ✅ You're building APIs or structured workflows

**Example Use Cases:**
- API endpoints requiring calculations
- Financial systems needing precision
- Real-time calculations in applications
- Batch processing of numeric data

### Use Bedrock AI Calculator When:
- ✅ You have natural language math queries
- ✅ You need explanations or step-by-step solutions
- ✅ You're working with complex mathematical concepts
- ✅ You need unit conversions or word problem solving
- ✅ You want mathematical reasoning and verification

**Example Use Cases:**
- ChatOps with natural language: "What's 15% of our $2M budget?"
- Educational applications needing explanations
- Complex financial calculations with context
- Mathematical research and analysis
- Customer support with calculation explanations

## Practical Examples

### Lambda MCP: API Integration
```python
# Fast, structured calculation for application logic
def calculate_discount(price, discount_rate):
    response = gateway_client.call_tool(
        "target-lambda-direct-calculator-mcp___multiply",
        {"a": price, "b": discount_rate}
    )
    return float(response.content[0].text)
```

### Bedrock AI: Natural Language Interface  
```python
# Natural language calculation with explanation
def explain_calculation(user_query):
    response = gateway_client.call_tool(
        "target-bedrock-claude-calculator", 
        {"prompt": f"Solve this step by step: {user_query}"}
    )
    return response.content[0].text  # Returns full explanation
```

## Cost Considerations

### Lambda MCP Calculator
- **Cost:** ~$0.0000002 per calculation
- **Speed:** <100ms response time
- **Precision:** Exact mathematical results

### Bedrock AI Calculator
- **Cost:** ~$0.001-0.01 per calculation (varies by complexity)
- **Speed:** 1-5 seconds response time  
- **Precision:** Very high, with reasoning validation

## Integration Patterns

### 1. Smart Routing
```python
def smart_calculate(query):
    # Simple structured math → Lambda MCP
    if is_simple_math(query):
        return lambda_calculator(query)
    # Complex/natural language → Bedrock AI
    else:
        return ai_calculator(query)
```

### 2. Validation Pattern
```python
def validated_calculation(query):
    # Get precise result from Lambda
    precise_result = lambda_calculator(query)
    # Get explanation from AI
    explanation = ai_calculator(f"Verify this calculation: {query}")
    return {"result": precise_result, "explanation": explanation}
```

### 3. Progressive Enhancement
```python
def enhanced_calculation(query):
    try:
        # Try fast Lambda first
        return lambda_calculator(query)
    except:
        # Fall back to AI for complex queries  
        return ai_calculator(query)
```

## Configuration Summary

Your gateway now provides:

1. **Precision Tools** (Lambda MCP) - Fast, exact, structured
2. **AI Reasoning** (Bedrock Claude) - Flexible, explanatory, natural language  
3. **Business Data** (Lambda MCP) - Application-specific information

This hybrid approach gives you the best of both worlds: speed and precision when you need it, intelligence and flexibility when you want it! 🚀