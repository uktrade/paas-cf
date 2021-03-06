// Code generated by counterfeiter. DO NOT EDIT.
package fakes

import (
	"sync"

	"github.com/alphagov/paas-cf/tools/metrics/pkg/health"
)

type FakeHealthServiceInterface struct {
	CountOpenEventsForServiceInRegionStub        func(string, string) (int, error)
	countOpenEventsForServiceInRegionMutex       sync.RWMutex
	countOpenEventsForServiceInRegionArgsForCall []struct {
		arg1 string
		arg2 string
	}
	countOpenEventsForServiceInRegionReturns struct {
		result1 int
		result2 error
	}
	countOpenEventsForServiceInRegionReturnsOnCall map[int]struct {
		result1 int
		result2 error
	}
	invocations      map[string][][]interface{}
	invocationsMutex sync.RWMutex
}

func (fake *FakeHealthServiceInterface) CountOpenEventsForServiceInRegion(arg1 string, arg2 string) (int, error) {
	fake.countOpenEventsForServiceInRegionMutex.Lock()
	ret, specificReturn := fake.countOpenEventsForServiceInRegionReturnsOnCall[len(fake.countOpenEventsForServiceInRegionArgsForCall)]
	fake.countOpenEventsForServiceInRegionArgsForCall = append(fake.countOpenEventsForServiceInRegionArgsForCall, struct {
		arg1 string
		arg2 string
	}{arg1, arg2})
	fake.recordInvocation("CountOpenEventsForServiceInRegion", []interface{}{arg1, arg2})
	fake.countOpenEventsForServiceInRegionMutex.Unlock()
	if fake.CountOpenEventsForServiceInRegionStub != nil {
		return fake.CountOpenEventsForServiceInRegionStub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	fakeReturns := fake.countOpenEventsForServiceInRegionReturns
	return fakeReturns.result1, fakeReturns.result2
}

func (fake *FakeHealthServiceInterface) CountOpenEventsForServiceInRegionCallCount() int {
	fake.countOpenEventsForServiceInRegionMutex.RLock()
	defer fake.countOpenEventsForServiceInRegionMutex.RUnlock()
	return len(fake.countOpenEventsForServiceInRegionArgsForCall)
}

func (fake *FakeHealthServiceInterface) CountOpenEventsForServiceInRegionCalls(stub func(string, string) (int, error)) {
	fake.countOpenEventsForServiceInRegionMutex.Lock()
	defer fake.countOpenEventsForServiceInRegionMutex.Unlock()
	fake.CountOpenEventsForServiceInRegionStub = stub
}

func (fake *FakeHealthServiceInterface) CountOpenEventsForServiceInRegionArgsForCall(i int) (string, string) {
	fake.countOpenEventsForServiceInRegionMutex.RLock()
	defer fake.countOpenEventsForServiceInRegionMutex.RUnlock()
	argsForCall := fake.countOpenEventsForServiceInRegionArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeHealthServiceInterface) CountOpenEventsForServiceInRegionReturns(result1 int, result2 error) {
	fake.countOpenEventsForServiceInRegionMutex.Lock()
	defer fake.countOpenEventsForServiceInRegionMutex.Unlock()
	fake.CountOpenEventsForServiceInRegionStub = nil
	fake.countOpenEventsForServiceInRegionReturns = struct {
		result1 int
		result2 error
	}{result1, result2}
}

func (fake *FakeHealthServiceInterface) CountOpenEventsForServiceInRegionReturnsOnCall(i int, result1 int, result2 error) {
	fake.countOpenEventsForServiceInRegionMutex.Lock()
	defer fake.countOpenEventsForServiceInRegionMutex.Unlock()
	fake.CountOpenEventsForServiceInRegionStub = nil
	if fake.countOpenEventsForServiceInRegionReturnsOnCall == nil {
		fake.countOpenEventsForServiceInRegionReturnsOnCall = make(map[int]struct {
			result1 int
			result2 error
		})
	}
	fake.countOpenEventsForServiceInRegionReturnsOnCall[i] = struct {
		result1 int
		result2 error
	}{result1, result2}
}

func (fake *FakeHealthServiceInterface) Invocations() map[string][][]interface{} {
	fake.invocationsMutex.RLock()
	defer fake.invocationsMutex.RUnlock()
	fake.countOpenEventsForServiceInRegionMutex.RLock()
	defer fake.countOpenEventsForServiceInRegionMutex.RUnlock()
	copiedInvocations := map[string][][]interface{}{}
	for key, value := range fake.invocations {
		copiedInvocations[key] = value
	}
	return copiedInvocations
}

func (fake *FakeHealthServiceInterface) recordInvocation(key string, args []interface{}) {
	fake.invocationsMutex.Lock()
	defer fake.invocationsMutex.Unlock()
	if fake.invocations == nil {
		fake.invocations = map[string][][]interface{}{}
	}
	if fake.invocations[key] == nil {
		fake.invocations[key] = [][]interface{}{}
	}
	fake.invocations[key] = append(fake.invocations[key], args)
}

var _ health.HealthServiceInterface = new(FakeHealthServiceInterface)
