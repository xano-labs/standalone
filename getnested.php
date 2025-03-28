static function getNestedPermissions($scope, $workspacePermissions, $rolePermissions) {
    $scopes = [$scope, "*"];

    foreach($scopes as $scopeValue) {
      $ret = \xano\Mapper::get(
        $scopeValue,
        $workspacePermissions
      );

      if (!is_null($ret)) return $ret;
    }

    foreach($scopes as $scopeValue) {
      $ret = \xano\Mapper::get(
        $scopeValue,
        $rolePermissions
      );

      if (!is_null($ret)) return $ret;
    }

    return self::getDefaultPermission($scope);
  }