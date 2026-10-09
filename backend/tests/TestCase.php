<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Tests\Concerns\InteractsWithApiTokens;

abstract class TestCase extends BaseTestCase
{
    use InteractsWithApiTokens;
}
