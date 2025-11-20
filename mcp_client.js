#!/usr/bin/env node
/**
 * MCP Client for Agent Core Gateway Calculator Target (Node.js)
 */

const { BedrockAgentRuntimeClient, InvokeAgentCommand } = require('@aws-sdk/client-bedrock-agent-runtime');
const readline = require('readline');

class CalculatorMCPClient {
    constructor() {
        this.gatewayId = 'a208194-askjulius-agentcore-gateway-mcp-iam';
        this.region = 'us-east-1';
        this.client = new BedrockAgentRuntimeClient({ region: this.region });
        this.sessionId = `mcp-client-${Date.now()}`;
    }

    async invokeCalculator(prompt) {
        try {
            console.log(`🔄 Processing: "${prompt}"`);
            
            const command = new InvokeAgentCommand({
                agentId: this.gatewayId,
                sessionId: this.sessionId,
                inputText: prompt
            });

            const response = await this.client.send(command);
            
            if (response.completion) {
                console.log(`✅ Result: ${response.completion}`);
                return { success: true, result: response.completion };
            } else {
                console.log('⚠️ No completion in response');
                return { success: false, error: 'No completion' };
            }
            
        } catch (error) {
            console.log(`❌ Error: ${error.message}`);
            return { success: false, error: error.message };
        }
    }

    async runTests() {
        console.log('🧮 Running Calculator Tests via Agent Core Gateway');
        console.log('=' * 55);
        
        const testCases = [
            'Calculate 12 plus 8',
            'What is 25 minus 9?',
            'Multiply 7 by 6',
            'Divide 84 by 12',
            'What is 3 to the power of 4?',
            'Find the square root of 49',
            'Calculate 6 factorial'
        ];

        let passed = 0;
        let failed = 0;

        for (let i = 0; i < testCases.length; i++) {
            console.log(`\nTest ${i + 1}/${testCases.length}: ${testCases[i]}`);
            const result = await this.invokeCalculator(testCases[i]);
            
            if (result.success) {
                passed++;
            } else {
                failed++;
            }
        }

        console.log('\n📊 Test Summary:');
        console.log(`✅ Passed: ${passed}`);
        console.log(`❌ Failed: ${failed}`);
        console.log(`📈 Success Rate: ${(passed / testCases.length * 100).toFixed(1)}%`);
    }

    async interactiveMode() {
        console.log('🧮 Interactive Calculator Mode');
        console.log('Type your calculations (or "quit" to exit)\n');

        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        const askQuestion = () => {
            rl.question('Calculator> ', async (input) => {
                if (input.toLowerCase().trim() === 'quit' || input.toLowerCase().trim() === 'exit') {
                    console.log('Goodbye! 👋');
                    rl.close();
                    return;
                }

                if (input.trim()) {
                    await this.invokeCalculator(input);
                }

                askQuestion();
            });
        };

        askQuestion();
    }

    async quickTest() {
        console.log('🚀 Quick Calculator Test');
        const result = await this.invokeCalculator('Calculate 10 plus 10');
        
        if (result.success) {
            console.log('🎯 Gateway integration working!');
        } else {
            console.log('❌ Gateway integration issue');
        }
    }
}

async function main() {
    const client = new CalculatorMCPClient();
    const mode = process.argv[2] || 'quick';

    switch (mode.toLowerCase()) {
        case 'test':
            await client.runTests();
            break;
        case 'interactive':
            await client.interactiveMode();
            break;
        case 'quick':
        default:
            await client.quickTest();
            break;
    }
}

if (require.main === module) {
    main().catch(console.error);
}

module.exports = CalculatorMCPClient;